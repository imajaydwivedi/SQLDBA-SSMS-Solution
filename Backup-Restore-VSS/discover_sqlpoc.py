#!/usr/bin/env python3
"""Query SqlPoc via AgHost-1A as WinRM intermediary using qemu-agent."""
import subprocess, json, base64, time, sys

def run_guest_cmd(vm, path, args, wait_secs=10):
    payload = json.dumps({
        "execute": "guest-exec",
        "arguments": {"path": path, "arg": args, "capture-output": True}
    })
    r = subprocess.run(["sudo", "virsh", "qemu-agent-command", vm, payload],
                       capture_output=True, text=True, timeout=15)
    if r.returncode != 0:
        return "", f"virsh error: {r.stderr}", -1
    pid = json.loads(r.stdout)["return"]["pid"]
    time.sleep(wait_secs)
    sp = json.dumps({"execute": "guest-exec-status", "arguments": {"pid": pid}})
    r2 = subprocess.run(["sudo", "virsh", "qemu-agent-command", vm, sp],
                        capture_output=True, text=True, timeout=15)
    ret = json.loads(r2.stdout)["return"]
    out = base64.b64decode(ret.get("out-data","")).decode("utf-8","replace") if ret.get("out-data") else ""
    err = base64.b64decode(ret.get("err-data","")).decode("utf-8","replace") if ret.get("err-data") else ""
    return out, err, ret.get("exitcode", -1)

import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from winrm_helper import HOSTS

_SQLPOC = HOSTS["SqlPoc"]

def ps_via_aghost(script, wait=15):
    """Run a PS script on SqlPoc via AgHost-1A (WinRM intermediary)."""
    wrapper = (
        f"$cred = [PSCredential]::new('SqlPoc\\{_SQLPOC['user']}',"
        f"(ConvertTo-SecureString '{_SQLPOC['pwd']}' -AsPlainText -Force));"
        f"Invoke-Command -ComputerName {_SQLPOC['ip']} -Credential $cred -ScriptBlock {{ {script} }}"
    )
    return run_guest_cmd("AgHost-1A", "powershell.exe",
                         ["-NonInteractive", "-NoProfile", "-Command", wrapper],
                         wait_secs=wait)

def header(msg):
    print(f"\n{'='*60}\n{msg}\n{'='*60}")

# Test connectivity first
header("Test: AgHost-1A -> SqlPoc WinRM")
out, err, code = ps_via_aghost("hostname; Invoke-Sqlcmd -ServerInstance '.' -Query 'SELECT @@SERVERNAME' | Out-String", wait=20)
print(f"ExitCode: {code}")
print(out or "(no output)")
if err: print("ERR:", err[:500])

header("SqlPoc: Databases")
out, err, _ = ps_via_aghost(
    "Invoke-Sqlcmd -ServerInstance '.' -Query \""
    "SELECT name, state_desc, recovery_model_desc FROM sys.databases ORDER BY name;\" "
    "-QueryTimeout 15 | Format-Table -AutoSize | Out-String",
    wait=20
)
print(out or "(no output)")
if err: print("ERR:", err[:500])

header("SqlPoc: Disks")
out, err, _ = ps_via_aghost(
    "Get-Disk | Select Number,OperationalStatus,IsReadOnly,"
    "@{N='SizeGB';E={[math]::Round($_.Size/1GB,0)}} | Format-Table | Out-String",
    wait=12
)
print(out or "(no output)")
if err: print("ERR:", err[:300])

header("SqlPoc: Backup Dirs")
out, err, _ = ps_via_aghost(
    "$r='';if(Test-Path 'E:\\Backups'){$b=Get-ChildItem 'E:\\Backups' -Filter '*.bak';"
    "$r+=\"Backups .bak: $($b.Count) files`n\";"
    "$r+=($b|Sort LastWriteTime -Desc|Select -First 5 Name,LastWriteTime|ft|Out-String)"
    "}else{$r+='E:\\Backups not found`n'};"
    "if(Test-Path 'E:\\TLogBackups'){$t=Get-ChildItem 'E:\\TLogBackups' -Filter '*.trn';"
    "$r+=\"TLogBackups .trn: $($t.Count) files`n\";"
    "$r+=($t|Sort LastWriteTime -Desc|Select -First 3 Name,LastWriteTime|ft|Out-String)"
    "}else{$r+='E:\\TLogBackups not found`n'};$r",
    wait=12
)
print(out or "(no output)")
if err: print("ERR:", err[:300])

print("\n=== SqlPoc Discovery Complete ===")
