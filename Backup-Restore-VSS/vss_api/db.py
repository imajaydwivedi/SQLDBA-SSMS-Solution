"""SQLite persistence layer for VSS Console.

Database : .venv/vss.db
Tables   : users, settings, audit_log, invitations, login_attempts

All user-facing queries use parameterised statements (? placeholders) to
prevent SQL injection.  The DB is never exposed directly to untrusted input.
"""
from __future__ import annotations
import sqlite3, re, threading, datetime, logging
from contextlib import contextmanager
from pathlib import Path
from typing import Optional, Any

log = logging.getLogger("vss.db")

HERE      = Path(__file__).parent
VENV_DIR  = HERE.parent / ".venv"
DB_PATH   = VENV_DIR / "vss.db"
CFG_PATH  = VENV_DIR / "config.env"

_lock = threading.Lock()

# ── Settings metadata: key → (category, label, is_secret) ────────────────────
SETTINGS_META: dict[str, tuple[str, str, bool]] = {
    "VSS_AUTH_ENABLED":     ("auth",         "Enable login gate (true/false)",           False),
    "VSS_SECRET_KEY":       ("auth",         "JWT signing secret (leave blank=auto)",    True),
    "SMTP_HOST":            ("smtp",         "SMTP hostname",                            False),
    "SMTP_PORT":            ("smtp",         "SMTP port",                                False),
    "SMTP_USER":            ("smtp",         "SMTP username / account",                  False),
    "SMTP_PWD":             ("smtp",         "SMTP password",                            True),
    "SMTP_FROM_ADDR":       ("smtp",         "Sender e-mail address",                    False),
    "SMTP_FROM_NAME":       ("smtp",         "Sender display name",                      False),
    "SMTP_STARTTLS":        ("smtp",         "Use STARTTLS (true/false)",                False),
    "GOOGLE_CLIENT_ID":     ("oauth_google", "Google OAuth Client ID",                  False),
    "GOOGLE_CLIENT_SECRET": ("oauth_google", "Google OAuth Client Secret",              True),
    "GITHUB_CLIENT_ID":     ("oauth_github", "GitHub OAuth Client ID",                  False),
    "GITHUB_CLIENT_SECRET": ("oauth_github", "GitHub OAuth Client Secret",              True),
    "SNAPSHOT_MAX_COUNT":   ("retention",    "Max snapshot count (0=unlimited)",         False),
    "SNAPSHOT_MAX_BYTES":   ("retention",    "Max snapshot storage in bytes",            False),
    "JOB_MAX_COUNT":        ("retention",    "Max finished-job history count",           False),
    "JOB_MAX_DAYS":         ("retention",    "Max job history age in days",              False),
}

# ── Connection ─────────────────────────────────────────────────────────────────
@contextmanager
def get_db():
    VENV_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH, check_same_thread=False, timeout=10)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    try:
        with _lock:
            yield conn
            conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def _now() -> str:
    return datetime.datetime.now().isoformat(timespec="seconds")


# ── Schema ─────────────────────────────────────────────────────────────────────
_SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    username       TEXT UNIQUE NOT NULL COLLATE NOCASE,
    email          TEXT UNIQUE COLLATE NOCASE,
    display_name   TEXT,
    password_hash  TEXT,
    provider       TEXT NOT NULL DEFAULT 'local',
    role           TEXT NOT NULL DEFAULT 'viewer' CHECK(role IN ('admin','editor','viewer')),
    is_active      INTEGER NOT NULL DEFAULT 1,
    created_at     TEXT,
    last_login     TEXT,
    created_by     TEXT,
    login_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until   TEXT
);

CREATE TABLE IF NOT EXISTS settings (
    key          TEXT PRIMARY KEY,
    value        TEXT,
    category     TEXT,
    label        TEXT,
    is_secret    INTEGER NOT NULL DEFAULT 0,
    updated_at   TEXT,
    updated_by   TEXT
);

CREATE TABLE IF NOT EXISTS audit_log (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp    TEXT NOT NULL,
    username     TEXT,
    action       TEXT NOT NULL,
    resource     TEXT,
    details      TEXT,
    ip_address   TEXT
);

CREATE TABLE IF NOT EXISTS invitations (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    email        TEXT NOT NULL COLLATE NOCASE,
    token        TEXT UNIQUE NOT NULL,
    role         TEXT NOT NULL DEFAULT 'viewer',
    created_by   TEXT,
    created_at   TEXT,
    expires_at   TEXT,
    used_at      TEXT
);

CREATE TABLE IF NOT EXISTS linked_accounts (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id        INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider       TEXT    NOT NULL,
    provider_email TEXT    NOT NULL COLLATE NOCASE,
    linked_at      TEXT    NOT NULL,
    UNIQUE(provider, provider_email)
);

CREATE TABLE IF NOT EXISTS login_attempts (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    ip           TEXT NOT NULL,
    username     TEXT,
    success      INTEGER NOT NULL DEFAULT 0,
    timestamp    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_login_attempts_ip_ts ON login_attempts(ip, timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_ts ON audit_log(timestamp);
"""


# ── Settings metadata: (category, label, is_secret) ───────────────────────────
SETTINGS_META: dict[str, tuple[str, str, bool]] = {
    "auth.enabled":              ("auth",         "Authentication enabled",       False),
    "auth.default_oauth_role":   ("auth",         "Default role for OAuth users", False),
    "smtp.host":                 ("smtp",         "SMTP Host",                   False),
    "smtp.port":                 ("smtp",         "SMTP Port",                   False),
    "smtp.user":                 ("smtp",         "SMTP Username",               False),
    "smtp.password":             ("smtp",         "SMTP Password",               True),
    "smtp.from_addr":            ("smtp",         "From Email",                  False),
    "smtp.from_name":            ("smtp",         "From Name",                   False),
    "smtp.starttls":             ("smtp",         "Use STARTTLS",                False),
    "oauth.google.client_id":    ("oauth.google", "Google Client ID",            False),
    "oauth.google.client_secret":("oauth.google", "Google Client Secret",        True),
    "oauth.github.client_id":    ("oauth.github", "GitHub Client ID",            False),
    "oauth.github.client_secret":("oauth.github", "GitHub Client Secret",        True),
    "retention.snapshot_max_count": ("retention", "Max snapshot count",          False),
    "retention.snapshot_max_bytes": ("retention", "Max snapshot bytes",          False),
    "retention.job_max_count":   ("retention",    "Max job history count",       False),
    "retention.job_max_days":    ("retention",    "Max job age (days)",          False),
    "query.viewer_login":        ("query",        "Viewer SQL login",            False),
    "query.viewer_pwd":          ("query",        "Viewer SQL password",         True),
    "query.editor_login":        ("query",        "Editor SQL login",            False),
    "query.editor_pwd":          ("query",        "Editor SQL password",         True),
    "query.sa_pwd":              ("query",        "SA SQL password (admin role)", True),
    "site.public_url":           ("site",         "Public base URL (e.g. https://vss.example.com) — overrides auto-detected URL behind reverse proxies", False),
}

# Default values for each setting
SETTINGS_DEFAULTS: dict[str, str] = {
    "auth.enabled": "true", "auth.default_oauth_role": "viewer",
    "smtp.host": "", "smtp.port": "587", "smtp.user": "", "smtp.password": "",
    "smtp.from_addr": "", "smtp.from_name": "VSS Console", "smtp.starttls": "true",
    "oauth.google.client_id": "", "oauth.google.client_secret": "",
    "oauth.github.client_id": "", "oauth.github.client_secret": "",
    "retention.snapshot_max_count": "200",
    "retention.snapshot_max_bytes": str(250 * 1024 ** 3),
    "retention.job_max_count": "500", "retention.job_max_days": "30",
    "query.viewer_login": "vss_reader",  "query.viewer_pwd": "",
    "query.editor_login": "vss_editor",  "query.editor_pwd": "",
    "query.sa_pwd": "",
    "site.public_url": "",
}

# config.env variable → settings key mapping
_ENV_MAP: dict[str, str] = {
    "VSS_AUTH_ENABLED":    "auth.enabled",
    "SMTP_HOST":           "smtp.host",
    "SMTP_PORT":           "smtp.port",
    "SMTP_USER":           "smtp.user",
    "SMTP_PWD":            "smtp.password",
    "SMTP_FROM_ADDR":      "smtp.from_addr",
    "SMTP_FROM_NAME":      "smtp.from_name",
    "SMTP_STARTTLS":       "smtp.starttls",
    "GOOGLE_CLIENT_ID":    "oauth.google.client_id",
    "GOOGLE_CLIENT_SECRET":"oauth.google.client_secret",
    "GITHUB_CLIENT_ID":    "oauth.github.client_id",
    "GITHUB_CLIENT_SECRET":"oauth.github.client_secret",
    "READER_PWD":          "query.viewer_pwd",
    "DEV_PWD":             "query.editor_pwd",
    "SA_PWD":              "query.sa_pwd",
    "VSS_PUBLIC_URL":      "site.public_url",
}


def init_db() -> None:
    """Create schema, seed settings from config.env, migrate users.json."""
    with get_db() as conn:
        conn.executescript(_SCHEMA)
    _seed_settings_from_env()
    _migrate_users_json()


# ── Settings ───────────────────────────────────────────────────────────────────
def _seed_settings_from_env() -> None:
    """Populate settings table from config.env for any key not yet in DB.

    Uses _ENV_MAP to translate ENV_VAR_NAMES → settings keys.
    Always refreshes non-empty env values so edits to config.env are picked up
    after a restart (but never overwrites values changed via the UI, unless they
    are still the default empty string).
    """
    env: dict[str, str] = {}
    if CFG_PATH.is_file():
        for line in CFG_PATH.read_text().splitlines():
            line = line.strip()
            if line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            env[k.strip()] = v.strip()
    # Also try to read from grafana.ini
    _try_merge_grafana(env)
    # Build settings-key → env-value map using _ENV_MAP
    env_by_setting: dict[str, str] = {}
    for env_key, setting_key in _ENV_MAP.items():
        if env.get(env_key):
            env_by_setting[setting_key] = env[env_key]

    with get_db() as conn:
        for key, (cat, label, secret) in SETTINGS_META.items():
            existing = conn.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
            env_val  = env_by_setting.get(key, "")
            if existing is None:
                # First run: insert with whatever value we have from env
                conn.execute(
                    "INSERT INTO settings(key,value,category,label,is_secret,updated_at,updated_by)"
                    " VALUES(?,?,?,?,?,?,?)",
                    (key, env_val, cat, label, int(secret), _now(), "system")
                )
            elif not existing["value"] and env_val:
                # Setting exists but is blank — fill from env (env edited manually)
                conn.execute(
                    "UPDATE settings SET value=?, updated_at=?, updated_by='env-reload'"
                    " WHERE key=?",
                    (env_val, _now(), key)
                )


def _try_merge_grafana(env: dict) -> None:
    """Best-effort: read SMTP/OAuth config from /etc/grafana/grafana.ini."""
    import configparser, os
    ini = "/etc/grafana/grafana.ini"
    if not os.access(ini, os.R_OK):
        return
    try:
        cp = configparser.RawConfigParser()
        cp.read(ini)
        if cp.has_section("smtp"):
            host = cp.get("smtp", "host", fallback="")
            if ":" in host:
                h, _, p = host.partition(":")
                env.setdefault("SMTP_HOST", h)
                env.setdefault("SMTP_PORT", p)
            env.setdefault("SMTP_USER",      cp.get("smtp", "user",         fallback=""))
            env.setdefault("SMTP_PWD",       cp.get("smtp", "password",     fallback=""))
            env.setdefault("SMTP_FROM_ADDR", cp.get("smtp", "from_address", fallback=""))
            env.setdefault("SMTP_FROM_NAME", cp.get("smtp", "from_name",    fallback=""))
        if cp.has_section("auth.google"):
            env.setdefault("GOOGLE_CLIENT_ID",
                           cp.get("auth.google", "client_id",     fallback=""))
            env.setdefault("GOOGLE_CLIENT_SECRET",
                           cp.get("auth.google", "client_secret", fallback=""))
        if cp.has_section("auth.github"):
            env.setdefault("GITHUB_CLIENT_ID",
                           cp.get("auth.github", "client_id",     fallback=""))
            env.setdefault("GITHUB_CLIENT_SECRET",
                           cp.get("auth.github", "client_secret", fallback=""))
    except Exception as e:
        log.debug("grafana.ini merge skipped: %s", e)


def get_setting(key: str, default: str = "") -> str:
    with get_db() as conn:
        row = conn.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
    return row["value"] if row else default


def get_all_settings() -> list[dict]:
    with get_db() as conn:
        rows = conn.execute(
            "SELECT key,value,category,label,is_secret,updated_at,updated_by"
            " FROM settings ORDER BY category,key"
        ).fetchall()
    return [dict(r) for r in rows]


def get_settings_by_category(category: str) -> list[dict]:
    with get_db() as conn:
        rows = conn.execute(
            "SELECT key,value,category,label,is_secret,updated_at,updated_by"
            " FROM settings WHERE category=? ORDER BY key",
            (category,)
        ).fetchall()
    return [dict(r) for r in rows]


def save_setting(key: str, value: str, user: str = "system") -> None:
    """Persist a setting to DB and sync back to config.env."""
    meta = SETTINGS_META.get(key, ("general", key, False))
    with get_db() as conn:
        conn.execute(
            "INSERT INTO settings(key,value,category,label,is_secret,updated_at,updated_by)"
            " VALUES(?,?,?,?,?,?,?)"
            " ON CONFLICT(key) DO UPDATE SET value=excluded.value,"
            "  updated_at=excluded.updated_at, updated_by=excluded.updated_by",
            (key, value, meta[0], meta[1], int(meta[2]), _now(), user)
        )
    _sync_key_to_env(key, value)


def _sync_key_to_env(key: str, value: str) -> None:
    """Write one key=value back into config.env (create if missing)."""
    try:
        lines: list[str] = []
        if CFG_PATH.is_file():
            lines = CFG_PATH.read_text().splitlines()
        found = False
        for i, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith("#") or "=" not in stripped:
                continue
            k = stripped.split("=", 1)[0].strip()
            if k == key:
                lines[i] = f"{key}={value}"
                found = True
                break
        if not found:
            lines.append(f"{key}={value}")
        CFG_PATH.write_text("\n".join(lines) + "\n")
    except Exception as e:
        log.warning("Could not sync setting %s to config.env: %s", key, e)


# ── User management ────────────────────────────────────────────────────────────
def get_user_by_username(username: str) -> Optional[dict]:
    with get_db() as conn:
        row = conn.execute(
            "SELECT * FROM users WHERE username=? AND is_active=1", (username,)
        ).fetchone()
    return dict(row) if row else None


def get_user_by_email(email: str) -> Optional[dict]:
    with get_db() as conn:
        row = conn.execute(
            "SELECT * FROM users WHERE email=? AND is_active=1", (email,)
        ).fetchone()
    return dict(row) if row else None


def get_user_by_id(uid: int) -> Optional[dict]:
    with get_db() as conn:
        row = conn.execute("SELECT * FROM users WHERE id=?", (uid,)).fetchone()
    return dict(row) if row else None


def list_users() -> list[dict]:
    with get_db() as conn:
        rows = conn.execute(
            "SELECT id,username,email,display_name,provider,role,is_active,"
            "       created_at,last_login,created_by"
            " FROM users ORDER BY created_at"
        ).fetchall()
    return [dict(r) for r in rows]


def create_user(username: str, email: str, password_hash: Optional[str],
                display_name: str = "", provider: str = "local",
                role: str = "viewer", created_by: str = "system") -> dict:
    now = _now()
    with get_db() as conn:
        conn.execute(
            "INSERT INTO users(username,email,display_name,password_hash,"
            "  provider,role,is_active,created_at,created_by)"
            " VALUES(?,?,?,?,?,?,1,?,?)",
            (username.lower(), email.lower() if email else None,
             display_name or username, password_hash, provider, role, now, created_by)
        )
        row = conn.execute("SELECT * FROM users WHERE username=?",
                           (username.lower(),)).fetchone()
    return dict(row)


def update_user(uid: int, **fields: Any) -> Optional[dict]:
    allowed = {"email", "display_name", "role", "is_active", "password_hash"}
    updates = {k: v for k, v in fields.items() if k in allowed}
    if not updates:
        return get_user_by_id(uid)
    cols = ", ".join(f"{k}=?" for k in updates)
    vals = list(updates.values()) + [uid]
    with get_db() as conn:
        conn.execute(f"UPDATE users SET {cols} WHERE id=?", vals)  # noqa: S608
        row = conn.execute("SELECT * FROM users WHERE id=?", (uid,)).fetchone()
    return dict(row) if row else None


def update_last_login(username: str) -> None:
    with get_db() as conn:
        conn.execute("UPDATE users SET last_login=?, login_attempts=0,"
                     " locked_until=NULL WHERE username=?",
                     (_now(), username.lower()))


# ── Login rate-limiting ────────────────────────────────────────────────────────
MAX_ATTEMPTS = 5
LOCKOUT_MIN  = 15


def check_locked(username: str) -> bool:
    """Return True if the account is currently locked."""
    with get_db() as conn:
        row = conn.execute(
            "SELECT locked_until FROM users WHERE username=?", (username.lower(),)
        ).fetchone()
    if not row or not row["locked_until"]:
        return False
    return _now() < row["locked_until"]


def record_failed_login(username: str) -> int:
    """Increment attempts; lock after MAX_ATTEMPTS. Returns remaining attempts."""
    with get_db() as conn:
        row = conn.execute(
            "SELECT login_attempts FROM users WHERE username=?", (username.lower(),)
        ).fetchone()
        if not row:
            return MAX_ATTEMPTS
        attempts = (row["login_attempts"] or 0) + 1
        locked_until = None
        if attempts >= MAX_ATTEMPTS:
            lu = datetime.datetime.now() + datetime.timedelta(minutes=LOCKOUT_MIN)
            locked_until = lu.isoformat(timespec="seconds")
        conn.execute(
            "UPDATE users SET login_attempts=?, locked_until=? WHERE username=?",
            (attempts, locked_until, username.lower())
        )
    return max(0, MAX_ATTEMPTS - attempts)


# ── Linked OAuth accounts ──────────────────────────────────────────────────────
def find_linked_user(provider: str, provider_email: str) -> Optional[dict]:
    with get_db() as conn:
        row = conn.execute(
            "SELECT u.* FROM users u"
            " JOIN linked_accounts la ON la.user_id=u.id"
            " WHERE la.provider=? AND la.provider_email=? AND u.is_active=1",
            (provider, provider_email.lower())
        ).fetchone()
    return dict(row) if row else None


def link_account(user_id: int, provider: str, provider_email: str) -> None:
    with get_db() as conn:
        conn.execute(
            "INSERT OR IGNORE INTO linked_accounts(user_id,provider,provider_email,linked_at)"
            " VALUES(?,?,?,?)",
            (user_id, provider, provider_email.lower(), _now())
        )


def get_linked_accounts(user_id: int) -> list[dict]:
    with get_db() as conn:
        rows = conn.execute(
            "SELECT provider, provider_email, linked_at FROM linked_accounts WHERE user_id=?",
            (user_id,)
        ).fetchall()
    return [dict(r) for r in rows]


def unlink_account(user_id: int, provider: str) -> None:
    with get_db() as conn:
        conn.execute(
            "DELETE FROM linked_accounts WHERE user_id=? AND provider=?",
            (user_id, provider)
        )


# ── Invitations ────────────────────────────────────────────────────────────────
def create_invitation(email: str, role: str, created_by: str) -> str:
    import secrets as _s
    token = _s.token_urlsafe(32)
    now   = _now()
    exp   = (datetime.datetime.now() + datetime.timedelta(days=7)).isoformat(timespec="seconds")
    with get_db() as conn:
        conn.execute(
            "INSERT INTO invitations(email,token,role,created_by,created_at,expires_at)"
            " VALUES(?,?,?,?,?,?)",
            (email.lower(), token, role, created_by, now, exp)
        )
    return token


def get_invitation(token: str) -> Optional[dict]:
    with get_db() as conn:
        row = conn.execute(
            "SELECT * FROM invitations"
            " WHERE token=? AND used_at IS NULL AND expires_at>?",
            (token, _now())
        ).fetchone()
    return dict(row) if row else None


def accept_invitation(token: str, username: str) -> None:
    with get_db() as conn:
        conn.execute(
            "UPDATE invitations SET used_at=? WHERE token=?", (_now(), token)
        )


# ── Audit log ──────────────────────────────────────────────────────────────────
def audit(username: str, action: str, resource: str = "", details: str = "",
          ip: str = "") -> None:
    with get_db() as conn:
        conn.execute(
            "INSERT INTO audit_log(timestamp,username,action,resource,details,ip_address)"
            " VALUES(?,?,?,?,?,?)",
            (_now(), username, action, resource, details, ip)
        )


def get_audit_log(limit: int = 200) -> list[dict]:
    with get_db() as conn:
        rows = conn.execute(
            "SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT ?", (limit,)
        ).fetchall()
    return [dict(r) for r in rows]


# ── IP-based rate limiting (login_attempts table) ─────────────────────────────
def record_ip_attempt(ip: str, username: str, success: bool) -> None:
    with get_db() as conn:
        conn.execute(
            "INSERT INTO login_attempts(ip,username,success,timestamp) VALUES(?,?,?,?)",
            (ip, username, int(success), _now())
        )


def is_ip_throttled(ip: str, window_minutes: int = 15, max_fails: int = 20) -> bool:
    cutoff = (datetime.datetime.now() - datetime.timedelta(minutes=window_minutes)).isoformat()
    with get_db() as conn:
        row = conn.execute(
            "SELECT COUNT(*) AS c FROM login_attempts"
            " WHERE ip=? AND success=0 AND timestamp>?",
            (ip, cutoff)
        ).fetchone()
    return row["c"] >= max_fails


# ── Migration: import users.json ───────────────────────────────────────────────
def _migrate_users_json() -> None:
    import json
    users_json = VENV_DIR / "users.json"
    if not users_json.is_file():
        return
    try:
        data = json.loads(users_json.read_text())
        for uname, u in data.items():
            with get_db() as conn:
                existing = conn.execute(
                    "SELECT id FROM users WHERE username=?", (uname,)
                ).fetchone()
            if not existing:
                create_user(
                    username=u.get("username", uname),
                    email=u.get("email", ""),
                    password_hash=u.get("password_hash"),
                    display_name=u.get("display_name", uname),
                    provider=u.get("provider", "local"),
                    role="admin" if "admin" in u.get("roles", []) else
                         "editor" if "editor" in u.get("roles", []) else "viewer",
                    created_by="migration",
                )
        log.info("Migrated %d user(s) from users.json", len(data))
        users_json.rename(users_json.with_suffix(".json.migrated"))
    except Exception as e:
        log.warning("users.json migration error: %s", e)
