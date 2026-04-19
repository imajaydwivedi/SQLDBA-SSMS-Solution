"""Pure-VSS Web API — FastAPI server.

Start with:
    cd SQLDBA-SSMS-Solution/Backup-Restore-VSS
    python3 -m uvicorn vss_api.server:app --host 0.0.0.0 --port 8765
or simply:
    ./start-vss-gui.sh
"""
import os, sys, glob, asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import List, Optional, Dict

HERE     = os.path.dirname(os.path.abspath(__file__))
VSS_ROOT = os.path.dirname(HERE)
sys.path.insert(0, VSS_ROOT)

from vss_api.config import (list_servers, add_server, remove_server,
                             TRANSPORT_PATH, REQDIR)
from vss_api.jobs import store
from winrm_helper import sqlcmd, sql_query_fast, sql_query_pyodbc

app = FastAPI(title="VSS Backup & Restore", version="1.0")


@app.on_event("startup")
async def _startup():
    store.set_loop(asyncio.get_running_loop())


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
    # Direct pyodbc connection to <host>:1433 (no PowerShell/WinRM hop) —
    # typical round-trip is ~20 ms vs ~15 s cold for Invoke-Sqlcmd, so the
    # Backup tab's DB list stays responsive on server re-selection.
    rows, err, rc = sql_query_pyodbc(
        host,
        "SELECT name, state_desc, recovery_model_desc "
        "FROM sys.databases WHERE database_id > 4 ORDER BY name",
    )
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
    rows, err, rc = sql_query_pyodbc(host,
        f"SELECT name FROM sys.databases WHERE name IN ({placeholders}) ORDER BY name",
        params=wanted)
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
