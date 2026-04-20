"""Pure-VSS Web API — FastAPI server.

Start with:
    cd SQLDBA-SSMS-Solution/Backup-Restore-VSS
    python3 -m uvicorn vss_api.server:app --host 0.0.0.0 --port 8765
or simply:
    ./start-vss-gui.sh
"""
import os, re, sys, glob, asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse
from pydantic import BaseModel, Field
from typing import List, Optional, Dict

HERE     = os.path.dirname(os.path.abspath(__file__))
VSS_ROOT = os.path.dirname(HERE)
sys.path.insert(0, VSS_ROOT)

from vss_api.config import (list_servers, add_server, remove_server,
                             TRANSPORT_PATH, REQDIR)
from vss_api.jobs import store
import winrm_helper
from winrm_helper import sql_query_mssql, sql_query_dev, run_ps

# ── Auth imports ──────────────────────────────────────────────────────────────
from vss_api.auth import AUTH_ENABLED, COOKIE_NAME, decode_token, ensure_default_admin, auth_enabled
from vss_api.auth_routes import router as _auth_router
from vss_api.settings_routes import router as _settings_router
from vss_api import db as _db

app = FastAPI(title="VSS Backup & Restore", version="1.0")

# ── Auth router (must be included before middleware and static mounts) ─────────
app.include_router(_auth_router)
app.include_router(_settings_router)

# ── Auth middleware ───────────────────────────────────────────────────────────
# Paths that never require a session token.
_PUBLIC_PREFIXES = ("/auth/", "/metrics", "/favicon", "/static/login")

@app.middleware("http")
async def _auth_gate(request: Request, call_next):
    """Redirect unauthenticated requests to /auth/login when auth is enabled."""
    if not auth_enabled():          # live DB check — respects Settings changes
        return await call_next(request)
    path = request.url.path
    if any(path.startswith(p) for p in _PUBLIC_PREFIXES):
        return await call_next(request)
    token   = request.cookies.get(COOKIE_NAME)
    payload = decode_token(token) if token else None
    if not payload:
        accept = request.headers.get("accept", "")
        if "text/html" in accept and not path.startswith("/api/"):
            return RedirectResponse("/auth/login", status_code=302)
        return JSONResponse({"error": "Not authenticated", "detail": "Session required."},
                            status_code=401)
    # Stash role on request state so endpoints can access it without re-decoding
    request.state.user_role = payload.get("role", "viewer")
    request.state.username  = payload.get("sub", "")
    return await call_next(request)

# Trust X-Forwarded-* headers from a reverse proxy (Cloudflare, nginx, …).
# This lets uvicorn log real client IPs and lets any future middleware that
# checks request.client.host work correctly behind a tunnel.
try:
    from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware  # noqa: E402
    app.add_middleware(ProxyHeadersMiddleware, trusted_hosts="*")
except ImportError:
    pass  # older uvicorn — no-op, everything still works

# Prometheus /metrics endpoint + HTTP + custom gauges. Must be installed
# before any routes are registered so the middleware wraps every handler.
from vss_api import metrics as _metrics  # noqa: E402
_metrics.install(app, TRANSPORT_PATH, list_servers)


# ── Retention constants ───────────────────────────────────────────────────────
SNAPSHOT_MAX_COUNT = 200
SNAPSHOT_MAX_BYTES = 250 * 1024 ** 3   # 250 GB


def apply_snapshot_retention() -> dict:
    """Enforce snapshot retention: keep at most SNAPSHOT_MAX_COUNT snapshots
    AND at most SNAPSHOT_MAX_BYTES total on disk.

    Snapshots are deleted oldest-first (by folder mtime) until BOTH limits are
    satisfied.  Returns a summary dict for logging / the API endpoint.
    """
    import shutil, datetime as _dt
    root = os.path.abspath(TRANSPORT_PATH)
    snaps = []
    for d in glob.glob(os.path.join(root, "*")):
        if not os.path.isdir(d):
            continue
        try:
            snaps.append((os.path.getmtime(d), d))
        except OSError:
            pass
    snaps.sort()                            # oldest first
    total_bytes = sum(_dir_size(p) for _, p in snaps)
    total_count = len(snaps)
    deleted, errors = [], []
    while snaps and (len(snaps) > SNAPSHOT_MAX_COUNT or total_bytes > SNAPSHOT_MAX_BYTES):
        mtime, path = snaps.pop(0)          # remove oldest
        name = os.path.basename(path)
        size = _dir_size(path)
        try:
            shutil.rmtree(path)
            deleted.append(name)
            total_bytes -= size
        except OSError as exc:
            errors.append({"name": name, "error": str(exc)})
    return {
        "deleted":      deleted,
        "errors":       errors,
        "remaining":    len(snaps),
        "total_bytes":  total_bytes,
        "total_human":  _human_size(total_bytes),
        "checked_at":   _dt.datetime.now().isoformat(timespec="seconds"),
    }


@app.post("/api/snapshots/prune", status_code=200)
def api_snapshot_prune():
    """Manually trigger snapshot retention enforcement and return a summary."""
    return apply_snapshot_retention()


@app.on_event("startup")
async def _startup():
    store.set_loop(asyncio.get_running_loop())
    # Initialise SQLite DB (creates tables, bootstraps settings, migrates JSON users)
    _db.init_db()
    # Ensure default admin account exists
    ensure_default_admin()
    # Start background snapshot-retention checker (every 10 minutes).
    asyncio.create_task(_snapshot_retention_loop())


async def _snapshot_retention_loop():
    """Periodically enforce snapshot retention in the background."""
    while True:
        await asyncio.sleep(600)           # 10-minute interval
        try:
            await asyncio.get_event_loop().run_in_executor(
                None, apply_snapshot_retention
            )
        except Exception:
            pass


# ── Servers ───────────────────────────────────────────────────────────────────

@app.get("/api/servers")
def api_servers():
    return list_servers()


class ServerIn(BaseModel):
    key: str; ip: str; user: str; pwd: str; role: str = "source"


@app.post("/api/servers", status_code=201)
def api_add_server(b: ServerIn):
    return add_server(b.key, b.ip, b.user, b.pwd, b.role)


@app.delete("/api/servers/{key}")
def api_del_server(key: str):
    try:
        remove_server(key)
    except KeyError as e:
        raise HTTPException(404, str(e))
    return {"deleted": key}


# ── Databases ─────────────────────────────────────────────────────────────────

@app.get("/api/databases")
def api_databases(host: str):
    # Direct mssql-python connection to <host>:1433 (no PowerShell/WinRM hop) —
    # typical round-trip is ~15 ms cold, ~2 ms on pool hit vs ~15 s cold for
    # Invoke-Sqlcmd, so the Backup tab's DB list stays responsive on server
    # re-selection.
    import time as _t
    t0 = _t.time()
    rows, err, rc = sql_query_mssql(
        host,
        "SELECT name, state_desc, recovery_model_desc "
        "FROM sys.databases WHERE database_id > 4 ORDER BY name",
    )
    _metrics.observe_sql(host, "list_databases", _t.time() - t0)
    if rc != 0:
        raise HTTPException(500, err[:400])
    return [{"name":     r[0],
             "state":    r[1] if len(r) > 1 else "?",
             "recovery": r[2] if len(r) > 2 else "?"} for r in rows if r]


@app.get("/api/databases/exists")
def api_databases_exists(host: str, names: str):
    """Return which of the comma-separated ``names`` currently exist on ``host``.

    Used by the Restore tab to warn the user about collisions before
    submitting the job (server-side re-check is performed by restore.py).
    """
    wanted = [n.strip() for n in names.split(",") if n.strip()]
    if not wanted:
        return {"existing": [], "checked": []}
    placeholders = ",".join("?" * len(wanted))
    import time as _t
    t0 = _t.time()
    rows, err, rc = sql_query_mssql(host,
        f"SELECT name FROM sys.databases WHERE name IN ({placeholders}) ORDER BY name",
        params=wanted)
    _metrics.observe_sql(host, "databases_exists", _t.time() - t0)
    if rc != 0:
        raise HTTPException(500, err[:400])
    wset = set(wanted)
    existing = sorted({r[0] for r in rows if r and r[0] in wset})
    return {"existing": existing, "checked": wanted}


# ── Snapshots ─────────────────────────────────────────────────────────────────

def _dir_size(path):
    """Sum of all file sizes under ``path``. Returns 0 on any error."""
    total = 0
    try:
        for root, _dirs, files in os.walk(path):
            for fn in files:
                try: total += os.path.getsize(os.path.join(root, fn))
                except OSError: pass
    except OSError:
        pass
    return total

def _human_size(n):
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or unit == "TB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{n} B"
        n /= 1024
    return f"{n:.1f} TB"

def _safe_snapshot_dir(name):
    """Resolve ``name`` to an absolute path inside TRANSPORT_PATH or abort."""
    if not name or "/" in name or "\\" in name or name.startswith("."):
        raise HTTPException(400, "Invalid snapshot name")
    root = os.path.abspath(TRANSPORT_PATH)
    path = os.path.abspath(os.path.join(root, name))
    if os.path.commonpath([root, path]) != root or not os.path.isdir(path):
        raise HTTPException(404, "Snapshot not found")
    return path


@app.get("/api/snapshots")
def api_snapshots():
    # Sort by directory mtime (newest first) — names can be sorted alphabet-
    # ically when the label is consistent but not when users pick different
    # labels across days. mtime is the actual backup completion timestamp.
    import datetime as _dt
    rows = []
    for d in glob.glob(os.path.join(TRANSPORT_PATH, "*")):
        if not os.path.isdir(d):
            continue
        try: mtime = os.path.getmtime(d)
        except OSError: continue
        dbs = [os.path.basename(x)
               for x in glob.glob(os.path.join(d, "*"))
               if os.path.isdir(x) and os.path.basename(x) != "writer_metadata"]
        size = _dir_size(d)
        rows.append({
            "name":       os.path.basename(d),
            "databases":  sorted(dbs),
            "path":       d,
            "mtime":      mtime,
            "created_at": _dt.datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M:%S"),
            "size_bytes": size,
            "size_human": _human_size(size),
        })
    rows.sort(key=lambda r: r["mtime"], reverse=True)
    return rows


@app.get("/api/snapshots/{name}")
def api_snapshot_detail(name: str):
    """Return per-file details for a single snapshot folder."""
    import datetime as _dt
    path = _safe_snapshot_dir(name)
    items = []
    total = 0
    for root, _dirs, files in os.walk(path):
        for fn in files:
            fp = os.path.join(root, fn)
            try: st = os.stat(fp)
            except OSError: continue
            total += st.st_size
            items.append({
                "rel":   os.path.relpath(fp, path),
                "size":  st.st_size,
                "human": _human_size(st.st_size),
                "mtime": st.st_mtime,
            })
    items.sort(key=lambda x: x["rel"])
    mtime = os.path.getmtime(path)
    return {
        "name":        name,
        "path":        path,
        "mtime":       mtime,
        "created_at":  _dt.datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M:%S"),
        "size_bytes":  total,
        "size_human":  _human_size(total),
        "file_count":  len(items),
        "files":       items,
    }


@app.delete("/api/snapshots/{name}")
def api_snapshot_delete(name: str):
    import shutil
    path = _safe_snapshot_dir(name)
    shutil.rmtree(path)
    return {"deleted": name}


@app.delete("/api/snapshots")
def api_snapshots_delete_all():
    """Delete every snapshot folder under TRANSPORT_PATH. Use with care."""
    import shutil
    root = os.path.abspath(TRANSPORT_PATH)
    deleted, failed = [], []
    for d in glob.glob(os.path.join(root, "*")):
        if not os.path.isdir(d):
            continue
        try:
            shutil.rmtree(d); deleted.append(os.path.basename(d))
        except OSError as e:
            failed.append({"name": os.path.basename(d), "error": str(e)})
    return {"deleted": deleted, "failed": failed}


# ── Jobs ──────────────────────────────────────────────────────────────────────

class BackupReq(BaseModel):
    label:     str
    source:    str
    databases: List[str]
    compress:  bool = False
    parallel:  int  = 1
    with_tlog: bool = False
    copy_only: bool = False                      # VSS_BT_COPY: preserve chain


class RestoreReq(BaseModel):
    snapshot:  str
    target:    str
    databases: Optional[List[str]] = None
    rename:    Optional[Dict[str, str]] = None   # {original: new_name}
    move_data: Optional[Dict[str, str]] = None   # {original: "E:\\Data\\..."}
    move_log:  Optional[Dict[str, str]] = None   # {original: "F:\\Log\\..."}
    overwrite: bool = False
    source:    Optional[str] = None              # tlog-bridge source host
    parallel:  int  = 1
    with_tlog: bool = True
    pitr:      Optional[str] = None              # "YYYY-MM-DDTHH:MM:SS"


@app.post("/api/jobs/backup", status_code=202)
def api_backup(r: BackupReq):
    job    = store.create("backup", r.label)
    script = os.path.join(HERE, "runners", "backup.py")
    cmd    = ["python3", "-u", script, r.label, r.source, ",".join(r.databases)]
    if r.compress:    cmd.append("--compress")
    if r.parallel > 1: cmd += ["--parallel", str(r.parallel)]
    if r.with_tlog:   cmd.append("--with-tlog")
    if r.copy_only:   cmd.append("--copy-only")
    store.run_subprocess(job, cmd, cwd=VSS_ROOT)
    return {"job_id": job.id}


@app.post("/api/jobs/restore", status_code=202)
def api_restore(r: RestoreReq):
    job    = store.create("restore", r.snapshot)
    script = os.path.join(HERE, "runners", "restore.py")
    cmd    = ["python3", "-u", script, r.snapshot, r.target]
    if r.databases:   cmd += ["--databases", ",".join(r.databases)]
    if r.rename:
        pairs = [f"{k}={v}" for k, v in r.rename.items() if k and v and k != v]
        if pairs:    cmd += ["--rename", ",".join(pairs)]
    if r.move_data:
        pairs = [f"{k}={v}" for k, v in r.move_data.items() if k and v]
        if pairs:    cmd += ["--move-data", ",".join(pairs)]
    if r.move_log:
        pairs = [f"{k}={v}" for k, v in r.move_log.items() if k and v]
        if pairs:    cmd += ["--move-log", ",".join(pairs)]
    if r.overwrite:   cmd.append("--overwrite")
    if r.source:      cmd += ["--source", r.source]
    if r.parallel > 1: cmd += ["--parallel", str(r.parallel)]
    if r.with_tlog:   cmd.append("--with-tlog")
    if r.pitr:        cmd += ["--stopat", r.pitr]
    store.run_subprocess(job, cmd, cwd=VSS_ROOT)
    return {"job_id": job.id}


@app.get("/api/jobs")
def api_jobs():
    return [{"id": j.id, "type": j.type, "label": j.label, "status": j.status,
             "started_at": j.started_at, "finished_at": j.finished_at,
             "exit_code": j.exit_code}
            for j in store.all()]


@app.get("/api/jobs/{jid}")
def api_job(jid: str):
    j = store.get(jid)
    if not j:
        raise HTTPException(404, "Job not found")
    return {"id": j.id, "type": j.type, "label": j.label, "status": j.status,
            "started_at": j.started_at, "finished_at": j.finished_at,
            "exit_code": j.exit_code, "lines": j.lines}


# ── WebSocket live progress ───────────────────────────────────────────────────

@app.websocket("/ws/{jid}")
async def ws_progress(ws: WebSocket, jid: str):
    await ws.accept()
    j = store.get(jid)
    if not j:
        await ws.send_text("[error] job not found\n__DONE__\n")
        return
    for line in list(j.lines):           # replay buffered lines
        await ws.send_text(line)
    if j.status in ("done", "failed"):
        await ws.send_text("__DONE__\n")
        return
    q = store.subscribe(jid)
    try:
        while True:
            line = await asyncio.wait_for(q.get(), timeout=120)
            await ws.send_text(line)
            if line.strip() == "__DONE__":
                break
    except (WebSocketDisconnect, asyncio.TimeoutError):
        pass
    finally:
        store.unsubscribe(jid, q)


# ── Query Window ─────────────────────────────────────────────────────────────

# Statements that must never be allowed through the developer account,
# regardless of SQL Server permissions (defence-in-depth).
_QRY_BLOCK = re.compile(
    r'\b(shutdown|xp_cmdshell|xp_regwrite|xp_regread|sp_oacreate|'
    r'sp_configure\s+[\'\"]show\s+advanced)',
    re.IGNORECASE,
)


class QueryReq(BaseModel):
    host:      str
    database:  str = "master"
    sql:       str
    row_limit: int = Field(default=2000, ge=1, le=5000)


@app.post("/api/query")
def api_query(r: QueryReq, request: Request):
    """Execute T-SQL using a role-appropriate SQL login.

    Roles → SQL logins:
      viewer → vss_reader (db_datareader only)
      editor → vss_developer (db_datareader + db_datawriter)
      admin  → sa (full access)

    GO batches are split, every result set returned.
    Dangerous statements are always blocked (defence-in-depth).
    """
    known = set(list_servers().keys())
    if r.host not in known:
        raise HTTPException(400, f"Unknown host: {r.host!r}")
    if _QRY_BLOCK.search(r.sql):
        raise HTTPException(403, "Query blocked: contains a forbidden statement.")

    # Determine caller's role (set by auth middleware; fallback for open mode)
    role = getattr(request.state, "user_role", "viewer")

    # Select SQL credentials from DB settings
    if role == "admin":
        login = "sa"
        pwd   = _db.get_setting("query.sa_pwd", "") or winrm_helper.SA_PWD
    elif role == "editor":
        login = _db.get_setting("query.editor_login", "vss_developer")
        pwd   = _db.get_setting("query.editor_pwd", "")
    else:  # viewer (default)
        login = _db.get_setting("query.viewer_login", "vss_reader")
        pwd   = _db.get_setting("query.viewer_pwd", "")

    if not pwd:
        raise HTTPException(503,
            f"SQL password for role '{role}' not configured. "
            "Go to Settings → Query to set it.")

    results, elapsed_ms, err = sql_query_dev(
        r.host, r.sql, database=r.database,
        timeout=60, row_limit=r.row_limit,
        login=login, pwd=pwd,
    )
    return {"results": results, "elapsed_ms": elapsed_ms, "error": err or None}


# ── Dev-login provisioning ────────────────────────────────────────────────────

class DevLoginSetupReq(BaseModel):
    host:    str
    dev_pwd: str


def _dev_login_ps(dev_user: str, dev_pwd: str, sa_pwd: str) -> str:
    """Return a PowerShell script that provisions ``dev_user`` on the local
    SQL Server instance with VIEW SERVER STATE, VIEW ANY DATABASE, and
    db_datareader + db_datawriter on every database (including msdb).
    """
    # Use plain replacement to avoid f-string / PowerShell brace conflicts.
    return """
$ErrorActionPreference = 'Stop'
$login = '__DEV_USER__'
$pwd   = '__DEV_PWD__'
$sa    = '__SA_PWD__'

# 1. Create / update the login and grant server-level permissions
$q1 = @"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = '$login' AND type_desc = 'SQL_LOGIN')
    CREATE LOGIN [$login] WITH PASSWORD = N'$pwd', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
ELSE
    ALTER LOGIN [$login] WITH PASSWORD = N'$pwd';
ALTER LOGIN [$login] ENABLE;
GRANT VIEW SERVER STATE TO [$login];
GRANT VIEW ANY DATABASE  TO [$login];
"@
Invoke-Sqlcmd -ServerInstance localhost -Username sa -Password $sa -Query $q1 -QueryTimeout 60
Write-Host "Server-level permissions granted."

# 2. Per-database user + roles (skip tempdb)
$dbs = Invoke-Sqlcmd -ServerInstance localhost -Username sa -Password $sa `
    -Query "SELECT name FROM sys.databases WHERE name <> 'tempdb' ORDER BY database_id" `
    -QueryTimeout 30
foreach ($row in $dbs) {
    $db = $row.name
    $q2 = @"
USE [$db];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = '$login')
    CREATE USER [$login] FOR LOGIN [$login];
IF IS_ROLEMEMBER('db_datareader', '$login') = 0 EXEC sp_addrolemember 'db_datareader', '$login';
IF IS_ROLEMEMBER('db_datawriter', '$login') = 0 EXEC sp_addrolemember 'db_datawriter', '$login';
GRANT VIEW DATABASE STATE TO [$login];
"@
    try {
        Invoke-Sqlcmd -ServerInstance localhost -Username sa -Password $sa -Query $q2 -QueryTimeout 30
        Write-Host "Configured: $db"
    } catch {
        Write-Host ("WARN $db : " + $_.Exception.Message)
    }
}
Write-Host "Done — $login provisioned."
""".replace("__DEV_USER__", dev_user) \
   .replace("__DEV_PWD__",  dev_pwd)  \
   .replace("__SA_PWD__",   sa_pwd)


def _persist_dev_pwd(pwd: str):
    """Update DEV_PWD in .venv/config.env and in the live winrm_helper module."""
    cfg_path = os.path.join(VSS_ROOT, ".venv", "config.env")
    try:
        with open(cfg_path) as f:
            lines = f.readlines()
        out = [l for l in lines if not l.startswith("DEV_PWD=")]
        out.append(f"DEV_PWD={pwd}\n")
        with open(cfg_path, "w") as f:
            f.writelines(out)
    except Exception:
        pass   # non-fatal — live update still works
    winrm_helper.DEV_PWD = pwd
    # Evict any stale dev connections so they reconnect with the new password.
    winrm_helper._DEV_POOL.clear()


@app.post("/api/setup/dev-login")
def api_setup_dev_login(r: DevLoginSetupReq):
    """Provision vss_developer on ``host`` and persist the password."""
    known = set(list_servers().keys())
    if r.host not in known:
        raise HTTPException(400, f"Unknown host: {r.host!r}")
    if not r.dev_pwd or len(r.dev_pwd) < 6:
        raise HTTPException(400, "dev_pwd must be at least 6 characters.")
    ps  = _dev_login_ps(winrm_helper.DEV_USER, r.dev_pwd, winrm_helper.SA_PWD)
    out, err, rc = run_ps(r.host, ps, timeout=180)
    if rc != 0:
        raise HTTPException(500, f"Setup failed on {r.host}:\n{err[:800]}\n{out[:400]}")
    _persist_dev_pwd(r.dev_pwd)
    return {"ok": True, "host": r.host, "output": out[:3000]}


# ── Static files (SPA) ────────────────────────────────────────────────────────

_STATIC = os.path.join(HERE, "static")
app.mount("/static", StaticFiles(directory=_STATIC), name="static")


@app.get("/")
def root():
    return FileResponse(os.path.join(_STATIC, "index.html"))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("vss_api.server:app", host="0.0.0.0", port=8765,
                reload=False, log_level="info")
