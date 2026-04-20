"""FastAPI auth router — /auth/* endpoints."""
from __future__ import annotations
import re, secrets, datetime
from typing import Optional

from fastapi import APIRouter, Form, Request, Response, HTTPException
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from pydantic import BaseModel

from vss_api import auth as _a, db

router = APIRouter(prefix="/auth", tags=["auth"])

# ── Helpers ───────────────────────────────────────────────────────────────────
def _base_url(request: Request) -> str:
    return str(request.base_url).rstrip("/")


def _set_cookie(response: Response, token: str) -> None:
    response.set_cookie(
        _a.COOKIE_NAME, token,
        max_age   = _a.TOKEN_HOURS * 3600,
        httponly  = True,
        samesite  = "lax",
        secure    = False,   # flip to True when served over HTTPS
    )


def _clear_cookie(response: Response) -> None:
    response.delete_cookie(_a.COOKIE_NAME)


# ── Public: provider list (used by login.html JS) ─────────────────────────────
@router.get("/providers")
def auth_providers():
    return {
        "google": _a.google_enabled(),
        "github": _a.github_enabled(),
        "smtp":   bool(db.get_setting("smtp.host")),
    }


# ── Serve login page ──────────────────────────────────────────────────────────
@router.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    # If already authenticated, bounce to home
    token = request.cookies.get(_a.COOKIE_NAME)
    if token and _a.decode_token(token):
        return RedirectResponse("/", status_code=302)
    from fastapi.responses import FileResponse
    import os
    page = os.path.join(os.path.dirname(__file__), "static", "login.html")
    return FileResponse(page, media_type="text/html")


# ── Local login (form POST) ───────────────────────────────────────────────────
@router.post("/login")
async def do_login(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
):
    ip = request.headers.get("x-forwarded-for", request.client.host or "")
    # IP-level throttle
    if db.is_ip_throttled(ip):
        raise HTTPException(429, "Too many failed attempts. Try again later.")
    # Normalise — accept username or email
    user = (db.get_user_by_username(username)
            or db.get_user_by_email(username))
    # Constant-time: always verify even if user is None (dummy hash)
    _dummy = "$2b$12$AAAAAAAAAAAAAAAAAAAAAA.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    ok = _a.verify_password(password, user["password_hash"] or _dummy) if user else False
    if not user or not ok or user.get("provider") not in ("local",):
        db.record_ip_attempt(ip, username, False)
        if user:
            remaining = db.record_failed_login(user["username"])
            if remaining == 0:
                raise HTTPException(401,
                    f"Account locked for 15 minutes after too many failed attempts.")
        raise HTTPException(401, "Invalid username or password.")
    if db.check_locked(user["username"]):
        raise HTTPException(403, "Account is temporarily locked. Try again later.")
    db.record_ip_attempt(ip, username, True)
    db.update_last_login(user["username"])
    db.audit(user["username"], "login", "local", "success", ip)
    token = _a.create_token(user["username"], user["email"] or "",
                            user["provider"], user["role"])
    resp  = JSONResponse({"ok": True, "username": user["username"],
                          "display_name": user.get("display_name", user["username"]),
                          "role": user["role"]})
    _set_cookie(resp, token)
    return resp


# ── Logout ────────────────────────────────────────────────────────────────────
@router.get("/logout")
async def logout():
    resp = RedirectResponse("/auth/login", status_code=302)
    _clear_cookie(resp)
    return resp


# ── Current user info ─────────────────────────────────────────────────────────
@router.get("/me")
async def me(request: Request):
    token = request.cookies.get(_a.COOKIE_NAME)
    if not token:
        raise HTTPException(401, "Not authenticated.")
    payload = _a.decode_token(token)
    if not payload:
        raise HTTPException(401, "Session expired.")
    u = db.get_user_by_username(payload["sub"])
    if not u or not u["is_active"]:
        raise HTTPException(401, "User not found or deactivated.")
    links = db.get_linked_accounts(u["id"])
    return {"username": u["username"], "email": u.get("email"),
            "display_name": u.get("display_name"), "provider": u["provider"],
            "role": u["role"], "linked_accounts": [l["provider"] for l in links]}


# ── Google OAuth ──────────────────────────────────────────────────────────────
@router.get("/oauth/google")
async def oauth_google(request: Request):
    if not _a.google_enabled():
        raise HTTPException(400, "Google OAuth is not configured.")
    state = _a.make_oauth_state("google")
    url   = _a.google_redirect_url(_base_url(request), state)
    return RedirectResponse(url, status_code=302)


@router.get("/callback/google")
async def callback_google(request: Request, code: str = "", state: str = "", error: str = ""):
    if error or not code:
        return RedirectResponse(f"/auth/login?error={error or 'access_denied'}", status_code=302)
    if not _a.consume_oauth_state(state, "google"):
        return RedirectResponse("/auth/login?error=invalid_state", status_code=302)
    info = _a.exchange_google_code(code, _base_url(request))
    if not info or not info.get("email"):
        return RedirectResponse("/auth/login?error=google_failed", status_code=302)
    return _oauth_finalize(request, info["email"], info.get("name", ""), "google")


# ── GitHub OAuth ──────────────────────────────────────────────────────────────
@router.get("/oauth/github")
async def oauth_github(request: Request):
    if not _a.github_enabled():
        raise HTTPException(400, "GitHub OAuth is not configured.")
    state = _a.make_oauth_state("github")
    url   = _a.github_redirect_url(_base_url(request), state)
    return RedirectResponse(url, status_code=302)


@router.get("/callback/github")
async def callback_github(request: Request, code: str = "", state: str = "", error: str = ""):
    if error or not code:
        return RedirectResponse(f"/auth/login?error={error or 'access_denied'}", status_code=302)
    if not _a.consume_oauth_state(state, "github"):
        return RedirectResponse("/auth/login?error=invalid_state", status_code=302)
    info = _a.exchange_github_code(code, _base_url(request))
    if not info or not info.get("email"):
        return RedirectResponse("/auth/login?error=github_failed", status_code=302)
    return _oauth_finalize(request, info["email"], info.get("name", ""), "github")


def _oauth_finalize(request: Request, email: str, name: str, provider: str) -> Response:
    """Find or create the OAuth user via linked accounts or email match, set cookie."""
    ip = request.headers.get("x-forwarded-for", request.client.host or "")
    # 1. Check linked accounts first (provider + email)
    user = db.find_linked_user(provider, email)
    if not user:
        # 2. Email match → auto-link
        user = db.get_user_by_email(email)
        if user:
            db.link_account(user["id"], provider, email)
    if not user:
        # 3. New OAuth user — provision with default role from settings
        default_role = db.get_setting("auth.default_oauth_role", "viewer")
        uname = re.sub(r"[^a-z0-9_]", "_", email.split("@")[0].lower())[:24]
        base = uname; i = 1
        while db.get_user_by_username(uname):
            uname = f"{base}{i}"; i += 1
        user = db.create_user(uname, email, None, display_name=name or uname,
                              provider=provider, role=default_role,
                              created_by=f"oauth:{provider}")
        db.link_account(user["id"], provider, email)
    if not user["is_active"]:
        return RedirectResponse("/auth/login?error=account_disabled", status_code=302)
    db.update_last_login(user["username"])
    db.audit(user["username"], "login", provider, "oauth success", ip)
    token = _a.create_token(user["username"], user["email"] or "",
                            provider, user["role"])
    resp  = RedirectResponse("/", status_code=302)
    resp.set_cookie(_a.COOKIE_NAME, token, max_age=_a.TOKEN_HOURS * 3600,
                    httponly=True, samesite="lax", secure=False)
    return resp


# ── Accept invitation ─────────────────────────────────────────────────────────
@router.get("/accept-invite", response_class=HTMLResponse)
async def accept_invite_page(token: str = "", request: Request = None):
    from fastapi.responses import FileResponse
    import os
    # Serve the login page with a special JS param
    page = os.path.join(os.path.dirname(__file__), "static", "login.html")
    return FileResponse(page, media_type="text/html")

class AcceptInviteBody(BaseModel):
    token:    str
    username: str
    password: str

@router.post("/accept-invite")
async def accept_invite(body: AcceptInviteBody, request: Request):
    inv = db.get_invitation(body.token)
    if not inv:
        raise HTTPException(400, "Invalid or expired invitation token.")
    err = _a.validate_password(body.password)
    if err:
        raise HTTPException(400, err)
    if db.get_user_by_username(body.username):
        raise HTTPException(409, "Username already exists.")
    ph   = _a.hash_password(body.password)
    user = db.create_user(body.username, inv["email"], ph,
                          provider="local", role=inv["role"],
                          created_by=f"invite:{inv['created_by']}")
    db.accept_invitation(body.token, body.username)
    token = _a.create_token(user["username"], user["email"] or "",
                            "local", user["role"])
    resp  = JSONResponse({"ok": True, "username": user["username"]})
    _set_cookie(resp, token)
    return resp


# ── Forgot password (sends reset email) ──────────────────────────────────────
class ForgotReq(BaseModel):
    email: str


@router.post("/forgot-password")
async def forgot_password(request: Request, body: ForgotReq):
    from vss_api.auth import _load_users, SECRET_KEY, ALGORITHM, send_email
    import secrets as _s, datetime as _dt
    from jose import jwt as _jwt
    users  = _load_users()
    target = next((u for u in users.values() if u["email"] == body.email.lower()), None)
    # Always return 200 to avoid user enumeration
    if not target:
        return {"ok": True}
    exp   = _dt.datetime.utcnow() + _dt.timedelta(hours=1)
    token = _jwt.encode({"sub": target["username"], "action": "reset", "exp": exp},
                        SECRET_KEY, algorithm=ALGORITHM)
    link  = f"{_base_url(request)}/auth/reset-password?token={token}"
    html  = f"""<p>Hi {target['display_name']},</p>
<p>Click the link below to reset your VSS Console password (valid 1 hour):</p>
<p><a href="{link}">{link}</a></p>
<p>If you did not request this, ignore this email.</p>"""
    ok, err = send_email(body.email, "VSS Console — Password Reset", html)
    if not ok:
        raise HTTPException(500, f"Could not send email: {err}")
    return {"ok": True}
