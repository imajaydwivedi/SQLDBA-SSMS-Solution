"""Settings & user management REST API (admin-only for most endpoints)."""
from __future__ import annotations
import re, secrets, datetime
from typing import Optional
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from vss_api import db, auth as _a

router = APIRouter(tags=["settings"])

# ── Auth guard helpers ─────────────────────────────────────────────────────────
def _current_user(request: Request) -> dict:
    token = request.cookies.get(_a.COOKIE_NAME)
    payload = _a.decode_token(token) if token else None
    if not payload:
        raise HTTPException(401, "Not authenticated")
    u = db.get_user_by_username(payload["sub"])
    if not u or not u["is_active"]:
        raise HTTPException(401, "User not found or inactive")
    return u

def _require_admin(request: Request) -> dict:
    u = _current_user(request)
    if u["role"] != "admin":
        raise HTTPException(403, "Admin role required")
    return u

def _require_editor(request: Request) -> dict:
    u = _current_user(request)
    if u["role"] not in ("admin", "editor"):
        raise HTTPException(403, "Editor or admin role required")
    return u

def _ip(request: Request) -> str:
    return request.headers.get("x-forwarded-for") or (request.client.host if request.client else "")


# ── Settings API ───────────────────────────────────────────────────────────────
@router.get("/api/settings")
def get_all_settings(request: Request):
    _require_admin(request)
    rows = db.get_all_settings()
    # Mask sensitive values unless the admin explicitly requests reveal
    return [
        {**r, "value": "••••••" if r.get("is_secret") and r.get("value") else r.get("value", "")}
        for r in rows
    ]

@router.get("/api/settings/{category}")
def get_settings_category(category: str, request: Request):
    _require_admin(request)
    rows = db.get_settings_by_category(category)
    return [
        {**r, "value": "••••••" if r.get("is_secret") and r.get("value") else r.get("value", "")}
        for r in rows
    ]

class SettingSave(BaseModel):
    key:   str
    value: str

@router.post("/api/settings")
def save_setting(body: SettingSave, request: Request):
    admin = _require_admin(request)
    # Basic key format validation — alphanumeric + dots only
    if not re.match(r'^[a-z0-9._]{2,64}$', body.key):
        raise HTTPException(400, "Invalid setting key format")
    db.save_setting(body.key, body.value, admin["username"])
    db.audit(admin["username"], "setting_change", body.key,
             f"key={body.key}", _ip(request))
    return {"ok": True}

@router.post("/api/settings/batch")
def save_settings_batch(body: list[SettingSave], request: Request):
    admin = _require_admin(request)
    for item in body:
        if not re.match(r'^[a-z0-9._]{2,64}$', item.key):
            raise HTTPException(400, f"Invalid setting key: {item.key}")
        db.save_setting(item.key, item.value, admin["username"])
    db.audit(admin["username"], "settings_batch", "",
             f"{len(body)} keys updated", _ip(request))
    return {"ok": True, "updated": len(body)}


# ── User management API ────────────────────────────────────────────────────────
@router.get("/api/users")
def list_users(request: Request):
    _require_admin(request)
    users = db.list_users()
    return [_safe_user(u) for u in users]

@router.get("/api/users/me")
def my_profile(request: Request):
    u = _current_user(request)
    links = db.get_linked_accounts(u["id"])
    return {**_safe_user(u), "linked_accounts": links}

class CreateUserBody(BaseModel):
    username: str
    email:    str
    password: str
    role:     str = "viewer"
    display_name: str = ""

@router.post("/api/users", status_code=201)
def create_user(body: CreateUserBody, request: Request):
    admin = _require_admin(request)
    if body.role not in ("admin", "editor", "viewer"):
        raise HTTPException(400, "Role must be admin, editor, or viewer")
    err = _a.validate_password(body.password)
    if err:
        raise HTTPException(400, err)
    if db.get_user_by_username(body.username):
        raise HTTPException(409, "Username already exists")
    if body.email and db.get_user_by_email(body.email):
        raise HTTPException(409, "Email already registered")
    ph = _a.hash_password(body.password)
    u  = db.create_user(body.username, body.email, ph,
                        display_name=body.display_name, provider="local",
                        role=body.role, created_by=admin["username"])
    db.audit(admin["username"], "user_create", body.username,
             f"role={body.role}", _ip(request))
    return _safe_user(u)

class UpdateUserBody(BaseModel):
    role:         Optional[str] = None
    display_name: Optional[str] = None
    is_active:    Optional[bool] = None
    password:     Optional[str] = None

@router.patch("/api/users/{uid}")
def update_user(uid: int, body: UpdateUserBody, request: Request):
    caller = _current_user(request)
    target = db.get_user_by_id(uid)
    if not target:
        raise HTTPException(404, "User not found")
    # Non-admins can only update their own display_name
    if caller["role"] != "admin" and caller["id"] != uid:
        raise HTTPException(403, "Cannot modify other users")
    if caller["role"] != "admin" and body.role is not None:
        raise HTTPException(403, "Only admins can change roles")
    fields: dict = {}
    if body.role is not None:
        if body.role not in ("admin", "editor", "viewer"):
            raise HTTPException(400, "Invalid role")
        fields["role"] = body.role
    if body.display_name is not None:
        fields["display_name"] = body.display_name[:80]
    if body.is_active is not None and caller["role"] == "admin":
        fields["is_active"] = int(body.is_active)
    if body.password is not None:
        err = _a.validate_password(body.password)
        if err:
            raise HTTPException(400, err)
        fields["password_hash"] = _a.hash_password(body.password)
    u = db.update_user(uid, **fields)
    db.audit(caller["username"], "user_update", str(uid),
             str(fields), _ip(request))
    return _safe_user(u)

@router.delete("/api/users/{uid}")
def deactivate_user(uid: int, request: Request):
    admin = _require_admin(request)
    target = db.get_user_by_id(uid)
    if not target:
        raise HTTPException(404, "User not found")
    if target["username"] == "admin":
        raise HTTPException(400, "Cannot deactivate the default admin")
    db.update_user(uid, is_active=0)
    db.audit(admin["username"], "user_deactivate", target["username"],
             "", _ip(request))
    return {"ok": True}


# ── Invitation API ─────────────────────────────────────────────────────────────
class InviteBody(BaseModel):
    email: str
    role:  str = "viewer"

@router.post("/api/users/invite")
def invite_user(body: InviteBody, request: Request):
    admin = _require_admin(request)
    if body.role not in ("admin", "editor", "viewer"):
        raise HTTPException(400, "Invalid role")
    if not re.match(r'^[^@\s]+@[^@\s]+\.[^@\s]+$', body.email):
        raise HTTPException(400, "Invalid email address")
    import os
    token   = db.create_invitation(body.email, body.role, admin["username"])
    base    = (db.get_setting("site.public_url") or os.environ.get("VSS_PUBLIC_URL", "")).rstrip("/") \
              or str(request.base_url).rstrip("/")
    link  = f"{base}/auth/accept-invite?token={token}"
    html  = (f"<p>You have been invited to VSS Console as <b>{body.role}</b>.</p>"
             f"<p><a href='{link}'>Accept invitation</a> (expires in 7 days)</p>")
    ok, err = _a.send_email(body.email, "VSS Console — Invitation", html)
    db.audit(admin["username"], "user_invite", body.email,
             f"role={body.role} smtp_ok={ok}", _ip(request))
    return {"ok": True, "link": link,
            "email_sent": ok, "email_error": err if not ok else None}


# ── Account linking API ────────────────────────────────────────────────────────
@router.get("/api/users/{uid}/linked-accounts")
def get_linked(uid: int, request: Request):
    caller = _current_user(request)
    if caller["role"] != "admin" and caller["id"] != uid:
        raise HTTPException(403, "Cannot view other users' linked accounts")
    return db.get_linked_accounts(uid)

@router.delete("/api/users/{uid}/linked-accounts/{provider}")
def unlink(uid: int, provider: str, request: Request):
    caller = _current_user(request)
    if caller["role"] != "admin" and caller["id"] != uid:
        raise HTTPException(403, "Cannot modify other users' linked accounts")
    db.unlink_account(uid, provider)
    db.audit(caller["username"], "unlink_account", f"{uid}/{provider}",
             "", _ip(request))
    return {"ok": True}


# ── Audit log ──────────────────────────────────────────────────────────────────
@router.get("/api/audit-log")
def audit_log(request: Request, limit: int = 200):
    _require_admin(request)
    return db.get_audit_log(min(limit, 1000))


# ── Setup vss_reader SQL login (db_datareader only on user databases) ──────────
class SetupReaderBody(BaseModel):
    host: str

@router.post("/api/setup/reader-login")
def setup_reader_login(body: SetupReaderBody, request: Request):
    _require_admin(request)
    from vss_api.config import list_servers
    from winrm_helper import run_ps
    srvs = list_servers()
    if body.host not in srvs:
        raise HTTPException(404, f"Unknown host: {body.host}")
    reader_pwd = db.get_setting("query.viewer_pwd", "")
    if not reader_pwd:
        raise HTTPException(400, "query.viewer_pwd not configured in Settings → Query")
    # vss_reader: db_datareader ONLY on user databases — no server-level grants.
    ps = (
        "$ErrorActionPreference = 'Stop'\n"
        "$login = 'vss_reader'\n"
        "$pwd   = '" + reader_pwd.replace("'", "''") + "'\n"
        "$sa    = '" + (db.get_setting("query.sa_pwd", "") or "").replace("'", "''") + "'\n"
        r"""
$q1 = @"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = '$login' AND type_desc = 'SQL_LOGIN')
    CREATE LOGIN [$login] WITH PASSWORD = N'$pwd', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
ELSE
    ALTER LOGIN [$login] WITH PASSWORD = N'$pwd';
ALTER LOGIN [$login] ENABLE;
"@
Invoke-Sqlcmd -ServerInstance localhost -Username sa -Password $sa -Query $q1 -QueryTimeout 60 -TrustServerCertificate
Write-Host "Login created / updated."

# Per-user-database: db_datareader only (database_id > 4, skip tempdb)
$dbs = Invoke-Sqlcmd -ServerInstance localhost -Username sa -Password $sa `
    -Query "SELECT name FROM sys.databases WHERE database_id > 4 AND state_desc = 'ONLINE' ORDER BY name" `
    -QueryTimeout 30 -TrustServerCertificate
foreach ($row in $dbs) {
    $db = $row.name
    $q2 = @"
USE [$db];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = '$login')
    CREATE USER [$login] FOR LOGIN [$login];
IF IS_ROLEMEMBER('db_datareader', '$login') = 0
    EXEC sp_addrolemember 'db_datareader', '$login';
"@
    try {
        Invoke-Sqlcmd -ServerInstance localhost -Username sa -Password $sa -Query $q2 -QueryTimeout 30 -TrustServerCertificate
        Write-Host "Configured: $db"
    } catch {
        Write-Host ("WARN $db : " + $_.Exception.Message)
    }
}
Write-Host "Done — $login (db_datareader only) provisioned."
"""
    )
    rc, out, err = run_ps(body.host, ps)
    if rc != 0:
        raise HTTPException(500, f"PowerShell failed: {err}")
    return {"ok": True, "output": out}


# ── Setup vss_editor SQL login (db_datareader + db_datawriter + server perms) ──
class SetupEditorBody(BaseModel):
    host: str

@router.post("/api/setup/editor-login")
def setup_editor_login(body: SetupEditorBody, request: Request):
    _require_admin(request)
    from vss_api.config import list_servers
    from winrm_helper import run_ps
    srvs = list_servers()
    if body.host not in srvs:
        raise HTTPException(404, f"Unknown host: {body.host}")
    editor_pwd = db.get_setting("query.editor_pwd", "")
    if not editor_pwd:
        raise HTTPException(400, "query.editor_pwd not configured in Settings → Query")
    sa_pwd = db.get_setting("query.sa_pwd", "")
    # vss_editor: db_datareader + db_datawriter on all databases except tempdb,
    # plus VIEW SERVER STATE, VIEW ANY DATABASE, VIEW DATABASE STATE.
    ps = (
        "$ErrorActionPreference = 'Stop'\n"
        "$login = 'vss_editor'\n"
        "$pwd   = '" + editor_pwd.replace("'", "''") + "'\n"
        "$sa    = '" + (sa_pwd or "").replace("'", "''") + "'\n"
        r"""
$q1 = @"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = '$login' AND type_desc = 'SQL_LOGIN')
    CREATE LOGIN [$login] WITH PASSWORD = N'$pwd', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
ELSE
    ALTER LOGIN [$login] WITH PASSWORD = N'$pwd';
ALTER LOGIN [$login] ENABLE;
GRANT VIEW SERVER STATE  TO [$login];
GRANT VIEW ANY DATABASE  TO [$login];
"@
Invoke-Sqlcmd -ServerInstance localhost -Username sa -Password $sa -Query $q1 -QueryTimeout 60 -TrustServerCertificate
Write-Host "Server-level permissions granted."

# All databases except tempdb (includes master, msdb for system queries)
$dbs = Invoke-Sqlcmd -ServerInstance localhost -Username sa -Password $sa `
    -Query "SELECT name FROM sys.databases WHERE name <> 'tempdb' AND state_desc = 'ONLINE' ORDER BY database_id" `
    -QueryTimeout 30 -TrustServerCertificate
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
        Invoke-Sqlcmd -ServerInstance localhost -Username sa -Password $sa -Query $q2 -QueryTimeout 30 -TrustServerCertificate
        Write-Host "Configured: $db"
    } catch {
        Write-Host ("WARN $db : " + $_.Exception.Message)
    }
}
# Grant EXECUTE on sp_WhoIsActive in master if the proc exists
$qSPA = @"
USE [master];
IF OBJECT_ID('dbo.sp_WhoIsActive') IS NOT NULL
BEGIN
    GRANT EXECUTE ON dbo.sp_WhoIsActive TO [$login];
    PRINT 'sp_WhoIsActive EXECUTE granted.';
END
"@
try {
    Invoke-Sqlcmd -ServerInstance localhost -Username sa -Password $sa -Query $qSPA -QueryTimeout 30 -TrustServerCertificate
} catch {
    Write-Host ("WARN sp_WhoIsActive grant: " + $_.Exception.Message)
}
Write-Host "Done — $login provisioned."
"""
    )
    rc, out, err = run_ps(body.host, ps)
    if rc != 0:
        raise HTTPException(500, f"PowerShell failed: {err}")
    return {"ok": True, "output": out}


# ── Helper: strip sensitive fields ────────────────────────────────────────────
def _safe_user(u: dict) -> dict:
    return {k: v for k, v in u.items()
            if k not in ("password_hash", "login_attempts", "locked_until")}
