#!/usr/bin/env python3
"""Reusable WinRM helper for the pure-VSS orchestrator.

Credentials and environment endpoints are loaded from
    <Backup-Restore-VSS>/.venv/config.env
which is gitignored. A template with dummy values lives at
    <Backup-Restore-VSS>/vss-venv/config.env
— copy it to .venv and edit for your lab (see vss-backup-kvm.md § 5).
"""
import os, winrm

_HERE = os.path.dirname(os.path.abspath(__file__))
_ENV_FILE = os.path.join(_HERE, ".venv", "config.env")


def load_config(path=_ENV_FILE):
    """Parse a KEY=VALUE env file and return it as a dict. Raises if missing."""
    if not os.path.isfile(path):
        raise FileNotFoundError(
            f"Missing credentials file: {path}\n"
            f"Copy {os.path.join(_HERE, 'vss-venv', 'config.env')} to {path} "
            f"and edit the values for your lab."
        )
    cfg = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            cfg[k.strip()] = v.strip()
    return cfg


_CFG = load_config()


def _require(key):
    v = _CFG.get(key, "")
    if not v:
        raise RuntimeError(f"{_ENV_FILE}: '{key}' is empty or missing.")
    return v


HOSTS = {
    _require("AGHOST_NAME"): {
        "ip":   _require("AGHOST_IP"),
        "user": _require("AGHOST_USER"),
        "pwd":  _require("AGHOST_PWD"),
    },
    _require("SQLPOC_NAME"): {
        "ip":   _require("SQLPOC_IP"),
        "user": _require("SQLPOC_USER"),
        "pwd":  _require("SQLPOC_PWD"),
    },
}

SA_PWD           = _require("SA_PWD")
SHARE_UNC        = _require("SHARE_UNC")
SHARE_LINUX_PATH = _require("SHARE_LINUX_PATH")
HV_NAME          = _require("HV_NAME")
HV_IP            = _require("HV_IP")

def get_session(host_key, read_timeout_sec=120, operation_timeout_sec=110):
    h = HOSTS[host_key]
    return winrm.Session(
        f"http://{h['ip']}:5985/wsman",
        auth=(h["user"], h["pwd"]),
        transport="ntlm",
        read_timeout_sec=read_timeout_sec,
        operation_timeout_sec=operation_timeout_sec,
    )

def run_ps(host_key, script, timeout=None):
    """Run a PowerShell script on the named host. Returns (stdout, stderr, rc).
    ``timeout`` is the WinRM read_timeout_sec (defaults to 120s); set it higher
    for long-running remote commands such as multi-GB VssBackup/VssRestore.
    """
    if timeout:
        s = get_session(host_key,
                        read_timeout_sec=timeout,
                        operation_timeout_sec=max(10, timeout - 10))
    else:
        s = get_session(host_key)
    r = s.run_ps(script)
    return r.std_out.decode("utf-8", "replace"), r.std_err.decode("utf-8", "replace"), r.status_code

def sqlcmd(host_key, query, timeout=60, sa=True):
    """Run a T-SQL query via Invoke-Sqlcmd on the named host (uses sa by default)."""
    auth = f"-Username 'sa' -Password '{SA_PWD}'" if sa else ""
    script = (
        f"Invoke-Sqlcmd -ServerInstance '.' {auth} -Query @'\n{query}\n'@ "
        f"-QueryTimeout {timeout} -ErrorAction Stop | Format-Table -AutoSize | Out-String"
    )
    return run_ps(host_key, script)

def push_file(host_key, local_path, remote_path):
    """Push a file to the remote Windows VM using SMB admin share.
    remote_path: Windows-style path like 'C:\\Scripts\\foo.ps1'
    """
    import subprocess, tempfile, ntpath
    h = HOSTS[host_key]
    # Convert C:\Scripts\foo.ps1 -> //HOST/C$/Scripts/foo.ps1
    drive, rest = remote_path.split(":", 1)
    unc_dir  = rest.rsplit("\\", 1)[0].replace("\\", "/").lstrip("/")
    unc_file = ntpath.basename(remote_path)   # must handle Windows separators on Linux host
    share = f"//{h['ip']}/{drive}$"
    # Ensure remote dir exists via WinRM first
    s = get_session(host_key)
    rdir = remote_path.rsplit("\\", 1)[0]
    s.run_ps(f"New-Item -ItemType Directory -Force '{rdir}' | Out-Null")
    # For text scripts (.ps1/.sql/.cmd/.bat), prepend UTF-8 BOM so Windows
    # PowerShell/sqlcmd reads non-ASCII chars correctly (otherwise treated as ANSI).
    push_src = local_path
    tmp = None
    ext = os.path.splitext(local_path)[1].lower()
    if ext in (".ps1", ".sql", ".cmd", ".bat", ".psm1"):
        with open(local_path, "rb") as f:
            data = f.read()
        if not data.startswith(b"\xef\xbb\xbf"):
            tmp = tempfile.NamedTemporaryFile(delete=False, suffix=ext)
            tmp.write(b"\xef\xbb\xbf" + data)
            tmp.close()
            push_src = tmp.name
    try:
        cmd = [
            "smbclient", share, "-U", f"{h['user']}%{h['pwd']}",
            "-c", f"cd \"{unc_dir}\"; put \"{push_src}\" \"{unc_file}\"; exit",
        ]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        # smbclient exits 0 even on per-file errors like NT_STATUS_OBJECT_NAME_INVALID;
        # detect them by scanning its output.
        combined = (r.stdout or "") + (r.stderr or "")
        if r.returncode != 0 or "NT_STATUS" in combined or "failed" in combined.lower():
            raise RuntimeError(f"smbclient push failed: {combined.strip()}")
    finally:
        if tmp:
            try: os.unlink(tmp.name)
            except OSError: pass
    return True

def pull_file(host_key, remote_path, local_path):
    """Pull a file from a Windows VM (remote_path like 'E:\\TLogBackups\\foo.trn')
    down to ``local_path`` on this Linux machine, using the admin share over
    smbclient. Avoids WinRM double-hop problems that break ``Copy-Item`` to
    third-party UNC destinations.
    """
    import subprocess, ntpath
    h = HOSTS[host_key]
    drive, rest = remote_path.split(":", 1)
    unc_dir  = rest.rsplit("\\", 1)[0].replace("\\", "/").lstrip("/")
    unc_file = ntpath.basename(remote_path)
    share    = f"//{h['ip']}/{drive}$"
    cmd = [
        "smbclient", share, "-U", f"{h['user']}%{h['pwd']}",
        "-c", f"cd \"{unc_dir}\"; get \"{unc_file}\" \"{local_path}\"; exit",
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    combined = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0 or "NT_STATUS" in combined or "failed" in combined.lower():
        raise RuntimeError(f"smbclient pull failed: {combined.strip()}")
    return True


def run_file(host_key, remote_path, args=""):
    """Run a PowerShell script file on the remote host with optional args."""
    script = f"& '{remote_path}' {args}"
    return run_ps(host_key, script)

if __name__ == "__main__":
    import sys
    host = sys.argv[1] if len(sys.argv) > 1 else "AgHost-1A"
    query = sys.argv[2] if len(sys.argv) > 2 else "SELECT @@SERVERNAME, GETDATE()"
    out, err, rc = sqlcmd(host, query)
    print(out)
    if err: print("STDERR:", err[:300])
    if rc != 0: print(f"RC: {rc}")
