"""Prometheus metrics for the VSS Backup & Restore web API.

Exposes a ``/metrics`` endpoint in the Prometheus exposition format, plus a
handful of custom gauges/counters beyond the standard HTTP ones:

* ``vss_api_jobs_total{type,status}``          — counter incremented on state change.
* ``vss_api_jobs_inflight{type}``              — gauge of running jobs by type.
* ``vss_api_job_duration_seconds{type}``       — histogram of completed job runtime.
* ``vss_api_snapshots_count``                  — gauge of snapshot folders.
* ``vss_api_snapshots_size_bytes``             — gauge of aggregate snapshot size.
* ``vss_api_servers_count{role}``              — gauge of registered servers.
* ``vss_api_sql_query_seconds{host,op}``       — histogram of mssql-python query
  latency so you can graph "Backup-tab responsiveness" in Grafana.

HTTP request count + latency come from ``prometheus_fastapi_instrumentator``
(default ``http_requests_total`` / ``http_request_duration_seconds``).
"""
from __future__ import annotations

import os, glob, time
from typing import Optional

from prometheus_client import Counter, Gauge, Histogram
from prometheus_fastapi_instrumentator import Instrumentator


# ── Counters / gauges / histograms ───────────────────────────────────────────
JOBS_TOTAL = Counter(
    "vss_api_jobs_total", "Job state transitions.", ["type", "status"])

JOBS_INFLIGHT = Gauge(
    "vss_api_jobs_inflight", "Jobs currently in the running state.", ["type"])

JOB_DURATION = Histogram(
    "vss_api_job_duration_seconds",
    "Wall-clock runtime of completed jobs.",
    ["type", "status"],
    buckets=(1, 5, 15, 30, 60, 120, 300, 600, 1800, 3600, 7200))

SNAPSHOTS_COUNT = Gauge(
    "vss_api_snapshots_count", "Number of snapshot folders on the transport share.")
SNAPSHOTS_SIZE  = Gauge(
    "vss_api_snapshots_size_bytes", "Aggregate size of all snapshot folders (bytes).")

SERVERS_COUNT = Gauge(
    "vss_api_servers_count", "Registered SQL servers.", ["role"])

SQL_QUERY_SECONDS = Histogram(
    "vss_api_sql_query_seconds",
    "Round-trip latency of mssql-python queries from the web API.",
    ["host", "op"],
    buckets=(0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10))


# ── Hooks ────────────────────────────────────────────────────────────────────
def on_job_start(type_: str) -> None:
    JOBS_INFLIGHT.labels(type=type_).inc()
    JOBS_TOTAL.labels(type=type_, status="running").inc()


def on_job_finish(type_: str, status: str, started_at: Optional[float]) -> None:
    JOBS_INFLIGHT.labels(type=type_).dec()
    JOBS_TOTAL.labels(type=type_, status=status).inc()
    if started_at is not None:
        JOB_DURATION.labels(type=type_, status=status).observe(
            max(0.0, time.time() - started_at))


def observe_sql(host: str, op: str, seconds: float) -> None:
    SQL_QUERY_SECONDS.labels(host=host, op=op).observe(seconds)


def refresh_static_gauges(transport_path: str, servers: list) -> None:
    """Recompute snapshot + server gauges. Called from a lightweight handler
    that runs before each /metrics scrape so Prometheus always sees fresh
    values without needing a background thread.
    """
    # Snapshots
    count, total = 0, 0
    for d in glob.glob(os.path.join(transport_path, "*")):
        if not os.path.isdir(d):
            continue
        count += 1
        try:
            for root, _dirs, files in os.walk(d):
                for fn in files:
                    try: total += os.path.getsize(os.path.join(root, fn))
                    except OSError: pass
        except OSError:
            pass
    SNAPSHOTS_COUNT.set(count)
    SNAPSHOTS_SIZE.set(total)

    # Servers
    by_role: dict = {}
    for s in servers:
        by_role[s.get("role", "unknown")] = by_role.get(s.get("role", "unknown"), 0) + 1
    # Reset all seen roles then set new values (avoid stale labels lingering
    # after a role was deleted).
    for role, n in by_role.items():
        SERVERS_COUNT.labels(role=role).set(n)


def install(app, transport_path: str, list_servers_fn) -> None:
    """Instrument a FastAPI ``app`` and expose ``/metrics``.

    * Adds HTTP request-count / latency metrics via ``Instrumentator``.
    * Registers a small dependency that refreshes snapshot + server gauges
      on every /metrics scrape.
    """
    inst = Instrumentator(
        should_group_status_codes=False,
        should_ignore_untemplated=True,
        excluded_handlers=["/metrics", "/static/.*"],
    )
    inst.instrument(app)
    inst.expose(app, endpoint="/metrics", include_in_schema=False, tags=["metrics"])

    # Refresh the "point-in-time" gauges on every scrape. We hook middleware
    # rather than a background thread so restarting the server can't leave a
    # zombie updater running.
    from starlette.middleware.base import BaseHTTPMiddleware

    class _ScrapeRefresh(BaseHTTPMiddleware):
        async def dispatch(self, request, call_next):
            if request.url.path == "/metrics":
                try:
                    refresh_static_gauges(transport_path, list_servers_fn())
                except Exception:
                    pass  # never break /metrics on a gauge refresh error
            return await call_next(request)

    app.add_middleware(_ScrapeRefresh)
