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
from winrm_helper import sqlcmd

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
    out, err, rc = sqlcmd(
        host,
        "SELECT name, state_desc, recovery_model_desc "
        "FROM sys.databases WHERE database_id > 4 ORDER BY name",
    )
    if rc != 0:
        raise HTTPException(500, err[:400])
    rows = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0] not in ("-", "name", "----"):
            rows.append({
                "name":     parts[0],
                "state":    parts[1] if len(parts) > 1 else "?",
                "recovery": parts[2] if len(parts) > 2 else "?",
            })
    return rows


@app.get("/api/databases/exists")
def api_databases_exists(host: str, names: str):
    """Return which of the comma-separated ``names`` currently exist on ``host``.

    Used by the Restore tab to warn the user about collisions before
    submitting the job (server-side re-check is performed by restore.py).
    """
    wanted = [n.strip() for n in names.split(",") if n.strip()]
    if not wanted:
        return {"existing": [], "checked": []}
    qlist = ",".join("'" + n.replace("'", "''") + "'" for n in wanted)
    out, err, rc = sqlcmd(host,
        f"SELECT name FROM sys.databases WHERE name IN ({qlist}) ORDER BY name")
    if rc != 0:
        raise HTTPException(500, err[:400])
    wset = set(wanted)
    existing = []
    for line in out.splitlines():
        tok = line.strip()
        if tok in wset:
            existing.append(tok)
    return {"existing": sorted(set(existing)), "checked": wanted}


# ── Snapshots ─────────────────────────────────────────────────────────────────

@app.get("/api/snapshots")
def api_snapshots():
    out = []
    for d in sorted(glob.glob(os.path.join(TRANSPORT_PATH, "*")), reverse=True):
        if not os.path.isdir(d):
            continue
        name = os.path.basename(d)
        dbs  = [os.path.basename(x)
                for x in glob.glob(os.path.join(d, "*"))
                if os.path.isdir(x)]
        out.append({"name": name, "databases": sorted(dbs), "path": d})
    return out


# ── Jobs ──────────────────────────────────────────────────────────────────────

class BackupReq(BaseModel):
    label:     str
    source:    str
    databases: List[str]
    compress:  bool = False
    parallel:  int  = 1
    with_tlog: bool = False


class RestoreReq(BaseModel):
    snapshot:  str
    target:    str
    databases: Optional[List[str]] = None
    rename:    Optional[Dict[str, str]] = None   # {original: new_name}
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
