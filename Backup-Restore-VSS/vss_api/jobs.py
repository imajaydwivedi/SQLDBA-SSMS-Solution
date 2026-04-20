"""Background job manager with asyncio WebSocket broadcasting.

Each job runs in a daemon thread (so long-running WinRM calls don't block
the event loop).  Progress lines are pushed to per-subscriber asyncio.Queues
so the WebSocket endpoint can stream them to the browser in real time.

Retention policy (enforced automatically on every new job):
  JOB_MAX_COUNT — keep at most this many finished jobs (running jobs are never pruned)
  JOB_MAX_DAYS  — prune finished jobs older than this many days
"""
import asyncio, subprocess, uuid, datetime, threading
from dataclasses import dataclass, field
from typing import List, Optional, Dict, Set

# Retention limits — adjust here if needed.
JOB_MAX_COUNT = 500
JOB_MAX_DAYS  = 30


@dataclass
class Job:
    id:          str
    type:        str           # "backup" | "restore"
    label:       str
    status:      str = "pending"   # pending | running | done | failed
    lines:       List[str] = field(default_factory=list)
    started_at:  Optional[str] = None
    finished_at: Optional[str] = None
    exit_code:   Optional[int] = None


class JobStore:
    def __init__(self):
        self._jobs: Dict[str, Job] = {}
        self._subs: Dict[str, Set[asyncio.Queue]] = {}
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._lock = threading.Lock()

    def set_loop(self, loop: asyncio.AbstractEventLoop) -> None:
        self._loop = loop

    def create(self, type_: str, label: str) -> Job:
        jid = str(uuid.uuid4())[:8]
        job = Job(id=jid, type=type_, label=label)
        with self._lock:
            self._jobs[jid] = job
            self._subs[jid] = set()
        self._prune()
        return job

    def _prune(self) -> None:
        """Remove finished jobs that exceed JOB_MAX_COUNT or JOB_MAX_DAYS.

        Running / pending jobs are never pruned so in-flight work is never lost.
        Oldest jobs (by started_at) are removed first.
        """
        cutoff = (
            datetime.datetime.now() - datetime.timedelta(days=JOB_MAX_DAYS)
        ).isoformat(timespec="seconds")

        with self._lock:
            finished = [
                j for j in self._jobs.values()
                if j.status not in ("running", "pending")
            ]
            # Sort oldest-first
            finished.sort(key=lambda j: j.started_at or "")
            # 1) Remove any job older than JOB_MAX_DAYS
            to_delete = {j.id for j in finished if (j.started_at or "") < cutoff}
            # 2) If still over JOB_MAX_COUNT, remove the oldest extras
            remaining = [j for j in finished if j.id not in to_delete]
            if len(remaining) > JOB_MAX_COUNT:
                extras = remaining[: len(remaining) - JOB_MAX_COUNT]
                to_delete.update(j.id for j in extras)
            for jid in to_delete:
                self._jobs.pop(jid, None)
                self._subs.pop(jid, None)

    def get(self, jid: str) -> Optional[Job]:
        return self._jobs.get(jid)

    def all(self) -> List[Job]:
        return sorted(self._jobs.values(),
                      key=lambda j: j.started_at or "", reverse=True)

    # ── internal ────────────────────────────────────────────────────────────
    def _push(self, jid: str, line: str) -> None:
        if not self._loop:
            return
        with self._lock:
            subs = set(self._subs.get(jid, []))
        for q in subs:
            asyncio.run_coroutine_threadsafe(q.put(line), self._loop)

    # ── WebSocket subscription ───────────────────────────────────────────────
    def subscribe(self, jid: str) -> asyncio.Queue:
        q: asyncio.Queue = asyncio.Queue()
        with self._lock:
            self._subs.setdefault(jid, set()).add(q)
        return q

    def unsubscribe(self, jid: str, q: asyncio.Queue) -> None:
        with self._lock:
            self._subs.get(jid, set()).discard(q)

    # ── subprocess execution (runs in a daemon thread) ───────────────────────
    def run_subprocess(self, job: Job, cmd: List[str], cwd: str = None) -> None:
        import time as _time
        try:
            from vss_api import metrics as _m
        except Exception:
            _m = None  # metrics import failures must never break job execution

        def _run():
            job.status     = "running"
            job.started_at = datetime.datetime.now().isoformat(timespec="seconds")
            started_epoch  = _time.time()
            if _m: _m.on_job_start(job.type)
            self._push(job.id, f"[VSS-GUI] cmd: {' '.join(cmd)}\n")
            try:
                proc = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                    cwd=cwd,
                )
                for line in proc.stdout:
                    job.lines.append(line)
                    self._push(job.id, line)
                proc.wait()
                job.exit_code = proc.returncode
                job.status    = "done" if proc.returncode == 0 else "failed"
            except Exception as exc:
                msg = f"[VSS-GUI error] {exc}\n"
                job.lines.append(msg)
                self._push(job.id, msg)
                job.status = "failed"
            finally:
                job.finished_at = datetime.datetime.now().isoformat(timespec="seconds")
                if _m:
                    try: _m.on_job_finish(job.type, job.status, started_epoch)
                    except Exception: pass
                self._push(job.id, "__DONE__\n")

        threading.Thread(target=_run, daemon=True).start()


# Module-level singleton shared by server.py and the WebSocket endpoint
store = JobStore()
