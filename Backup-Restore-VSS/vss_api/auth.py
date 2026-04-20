# Authentication helpers for VSS Web API -- backed by SQLite via vss_api.db.
from __future__ import annotations
import re, secrets, datetime, smtplib, logging, urllib.parse
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path
from typing import Optional

import bcrypt as _bcrypt
from jose import jwt, JWTError
from vss_api import db

log = logging.getLogger("vss.auth")

ALGORITHM   = "HS256"
TOKEN_HOURS = 24
COOKIE_NAME = "vss_token"
VENV_DIR    = db.VENV_DIR
SECRET_F    = VENV_DIR / "auth_secret.key"


def _get_secret():
    if SECRET_F.is_file():
        s = SECRET_F.read_text().strip()
        if s:
            return s
    s = secrets.token_hex(32)
    VENV_DIR.mkdir(parents=True, exist_ok=True)
    SECRET_F.write_text(s)
    SECRET_F.chmod(0o600)
    return s

SECRET_KEY   = _get_secret()
AUTH_ENABLED = True   # real check via auth_enabled()


def auth_enabled():
    return db.get_setting("auth.enabled", "true").lower() not in ("false", "0", "no")


# Password complexity
_COMPLEX_RE = re.compile(
    r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)"
    r'(?=.*[!@#$%^&*()\-_=+\[\]{};:\'",.<>/?\\|`~]).{8,}$'
)

def validate_password(pwd):
    if not _COMPLEX_RE.match(pwd):
        return ("Password must be >= 8 chars and include uppercase, lowercase, "
                "a digit, and a special character.")
    return None

def hash_password(pwd):
    return _bcrypt.hashpw(pwd.encode()[:72], _bcrypt.gensalt(12)).decode()

def verify_password(plain, hashed):
    try:
        return _bcrypt.checkpw(plain.encode()[:72], hashed.encode())
    except Exception:
        return False


# JWT
def create_token(username, email, provider, role):
    exp = datetime.datetime.utcnow() + datetime.timedelta(hours=TOKEN_HOURS)
    return jwt.encode(
        {"sub": username, "email": email or "", "provider": provider,
         "role": role, "exp": exp},
        SECRET_KEY, algorithm=ALGORITHM,
    )

def decode_token(token):
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        return None


# OAuth
def google_enabled():
    return bool(db.get_setting("oauth.google.client_id") and
                db.get_setting("oauth.google.client_secret"))

def github_enabled():
    return bool(db.get_setting("oauth.github.client_id") and
                db.get_setting("oauth.github.client_secret"))

GOOGLE_AUTH_URL  = "https://accounts.google.com/o/oauth2/v2/auth"
GITHUB_AUTH_URL  = "https://github.com/login/oauth/authorize"
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
GITHUB_TOKEN_URL = "https://github.com/login/oauth/access_token"
GOOGLE_USER_URL  = "https://www.googleapis.com/oauth2/v3/userinfo"
GITHUB_USER_URL  = "https://api.github.com/user"
GITHUB_EMAIL_URL = "https://api.github.com/user/emails"

_OAUTH_STATES = {}

def make_oauth_state(provider):
    state = secrets.token_urlsafe(24)
    _OAUTH_STATES[state] = {"provider": provider}
    return state

def consume_oauth_state(state, provider):
    entry = _OAUTH_STATES.pop(state, None)
    return bool(entry and entry["provider"] == provider)

def google_redirect_url(base_url, state):
    params = {"client_id": db.get_setting("oauth.google.client_id"),
              "redirect_uri": f"{base_url}/auth/callback/google",
              "response_type": "code", "scope": "openid email profile",
              "state": state, "access_type": "online"}
    return f"{GOOGLE_AUTH_URL}?{urllib.parse.urlencode(params)}"

def github_redirect_url(base_url, state):
    params = {"client_id": db.get_setting("oauth.github.client_id"),
              "redirect_uri": f"{base_url}/auth/callback/github",
              "scope": "read:user user:email", "state": state}
    return f"{GITHUB_AUTH_URL}?{urllib.parse.urlencode(params)}"

def exchange_google_code(code, base_url):
    import httpx
    try:
        r = httpx.post(GOOGLE_TOKEN_URL, data={
            "code": code,
            "client_id": db.get_setting("oauth.google.client_id"),
            "client_secret": db.get_setting("oauth.google.client_secret"),
            "redirect_uri": f"{base_url}/auth/callback/google",
            "grant_type": "authorization_code",
        }, timeout=15)
        tok = r.json().get("access_token")
        if not tok:
            return None
        info = httpx.get(GOOGLE_USER_URL,
                         headers={"Authorization": f"Bearer {tok}"}, timeout=10).json()
        return {"email": info.get("email"), "name": info.get("name", "")}
    except Exception as e:
        log.warning("Google exchange error: %s", e)
        return None

def exchange_github_code(code, base_url):
    import httpx
    try:
        r = httpx.post(GITHUB_TOKEN_URL, data={
            "code": code,
            "client_id": db.get_setting("oauth.github.client_id"),
            "client_secret": db.get_setting("oauth.github.client_secret"),
            "redirect_uri": f"{base_url}/auth/callback/github",
        }, headers={"Accept": "application/json"}, timeout=15)
        tok = r.json().get("access_token")
        if not tok:
            return None
        hdrs = {"Authorization": f"token {tok}", "Accept": "application/json"}
        user  = httpx.get(GITHUB_USER_URL, headers=hdrs, timeout=10).json()
        email = user.get("email")
        if not email:
            emails = httpx.get(GITHUB_EMAIL_URL, headers=hdrs, timeout=10).json()
            email = next((e["email"] for e in emails
                          if e.get("primary") and e.get("verified")), None)
        return {"email": email, "name": user.get("name") or user.get("login", "")}
    except Exception as e:
        log.warning("GitHub exchange error: %s", e)
        return None


# SMTP
def send_email(to_addr, subject, html_body):
    host  = db.get_setting("smtp.host", "")
    port  = int(db.get_setting("smtp.port", "587"))
    user  = db.get_setting("smtp.user", "")
    pwd   = db.get_setting("smtp.password", "")
    from_ = db.get_setting("smtp.from_addr", user)
    fname = db.get_setting("smtp.from_name", "VSS Console")
    tls   = db.get_setting("smtp.starttls", "true").lower() not in ("false", "0", "no")
    if not host:
        return False, "SMTP not configured"
    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"]    = f"{fname} <{from_}>"
        msg["To"]      = to_addr
        msg.attach(MIMEText(html_body, "html"))
        with smtplib.SMTP(host, port, timeout=15) as s:
            if tls:
                s.starttls()
            if user:
                s.login(user, pwd)
            s.sendmail(from_, [to_addr], msg.as_string())
        return True, ""
    except Exception as exc:
        log.warning("SMTP error: %s", exc)
        return False, str(exc)


# Default admin
def ensure_default_admin():
    if db.get_user_by_username("admin"):
        return
    ph = hash_password("LetMe!n4SQLMonitor")
    db.create_user("admin", "admin@localhost", ph,
                   display_name="Admin", provider="local",
                   role="admin", created_by="system")
    log.info("Default admin user created (username: admin)")
