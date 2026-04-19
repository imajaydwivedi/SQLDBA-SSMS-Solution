"""Server registry + shared constants for the VSS API.

Built-in servers (AgHost-1A / SqlPoc) come from .venv/config.env and cannot
be removed via the API.  Extra servers are persisted in vss_api/servers.json.
"""
import os, json, sys

HERE     = os.path.dirname(os.path.abspath(__file__))
VSS_ROOT = os.path.dirname(HERE)           # Backup-Restore-VSS/
REQDIR   = os.path.join(VSS_ROOT, "VssRequester")
sys.path.insert(0, VSS_ROOT)

from winrm_helper import load_config, HOSTS

_cfg = load_config()
TRANSPORT_PATH = _cfg.get("SHARE_LINUX_PATH", "/hyperactive/vss-transport")
SHARE_UNC      = _cfg.get("SHARE_UNC", r"\\192.168.122.1\vss-transport")

# Built-in servers derived from .venv/config.env
BUILTIN_SERVERS: dict = {}
for _i, (_k, _v) in enumerate(HOSTS.items()):
    BUILTIN_SERVERS[_k] = {
        "ip":      _v["ip"],
        "user":    _v["user"],
        "pwd":     _v["pwd"],
        "role":    "source" if _i == 0 else "target",
        "builtin": True,
    }

SERVERS_JSON = os.path.join(HERE, "servers.json")


def _extra() -> dict:
    if not os.path.isfile(SERVERS_JSON):
        return {}
    with open(SERVERS_JSON) as f:
        return json.load(f)


def list_servers() -> dict:
    """Return combined built-in + extra servers (pwd redacted)."""
    merged = {**BUILTIN_SERVERS, **_extra()}
    # Never expose passwords to the frontend
    return {k: {kk: vv for kk, vv in v.items() if kk != "pwd"}
            for k, v in merged.items()}


def list_servers_with_pwd() -> dict:
    """Return combined servers including passwords (for internal use only)."""
    return {**BUILTIN_SERVERS, **_extra()}


def add_server(key: str, ip: str, user: str, pwd: str, role: str = "source") -> dict:
    extras = _extra()
    extras[key] = {"ip": ip, "user": user, "pwd": pwd, "role": role, "builtin": False}
    with open(SERVERS_JSON, "w") as f:
        json.dump(extras, f, indent=2)
    return {k: v for k, v in extras[key].items() if k != "pwd"}


def remove_server(key: str) -> None:
    extras = _extra()
    if key not in extras:
        raise KeyError(f"'{key}' not found or is a built-in server (edit .venv/config.env)")
    del extras[key]
    with open(SERVERS_JSON, "w") as f:
        json.dump(extras, f, indent=2)
