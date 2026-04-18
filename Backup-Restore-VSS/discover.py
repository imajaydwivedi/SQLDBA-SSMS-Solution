#!/usr/bin/env python3
"""Discovery script: query AgHost-1A and SqlPoc via qemu-agent."""
import subprocess, json, base64, time, sys

def run_guest_cmd(vm, path, args, wait_secs=8):
    payload = json.dumps({
        "execute": "guest-exec",
        "arguments": {"path": path, "arg": args, "capture-output": True}
    })
    r = subprocess.run(["sudo", "virsh", "qemu-agent-command", vm, payload],
                       capture_output=True, text=True, timeout=15)
    if r.returncode != 0:
        return "", r.stderr, -1
    pid = json.loads(r.stdout)["return"]["pid"]
    time.sleep(wait_secs)
    sp = json.dumps({"execute": "guest-exec-status", "arguments": {"pid": pid}})
    r2 = subprocess.run(["sudo", "virsh", "qemu-agent-command", vm, sp],
                        capture_output=True, text=True, timeout=15)
    ret = json.loads(r2.stdout)["return"]
    out = base64.b64decode(ret.get("out-data","")).decode("utf-8","replace") if ret.get("out-data") else ""
    err = base64.b64decode(ret.get("err-data","")).decode("utf-8","replace") if ret.get("err-data") else ""
    return out, err, ret.get("exitcode", -1)

def ps(vm, script, wait=10):
    return run_guest_cmd(vm, "powershell.exe",
                         ["-NonInteractive", "-NoProfile", "-Command", script],
                         wait_secs=wait)

def header(msg):
    print(f"\n{'='*60}\n{msg}\n{'='*60}")

# ── AgHost-1A ──────────────────────────────────────────────────
header("AgHost-1A: Databases & Recovery Models")
out, err, _ = ps("AgHost-1A", (
    "Invoke-Sqlcmd -ServerInstance '.' -Query \""
    "SELECT name, state_desc, recovery_model_desc "
    "FROM sys.databases "
    "WHERE name NOT IN ('master','model','msdb','tempdb') "
    "ORDER BY name;\" -QueryTimeout 15 | Format-Table -AutoSize | Out-String"
))
print(out or "(no output)"); print(err or "")

header("AgHost-1A: T-Log SQL Agent Job")
out, err, _ = ps("AgHost-1A", (
    "Invoke-Sqlcmd -ServerInstance '.' -Query \""
    "SELECT j.name, j.enabled, CAST(js.last_run_date AS VARCHAR) AS LastRunDate "
    "FROM msdb.dbo.sysjobs j "
    "JOIN msdb.dbo.sysjobsteps js ON j.job_id=js.job_id AND js.step_id=1 "
    "WHERE j.name LIKE '%TLog%' OR j.name LIKE '%VSS%';\" -QueryTimeout 15 | "
    "Format-Table -AutoSize | Out-String"
))
print(out if out.strip() else "  No matching T-log job found."); print(err or "")

header("AgHost-1A: Backup Directories")
script = (
    "$r='';if(Test-Path 'E:\\\\TLogBackups'){"
    "$f=Get-ChildItem 'E:\\\\TLogBackups' -Filter '*.trn';"
    "$r+=\"TLogBackups .trn count: $($f.Count)`n\";"
    "$r+=($f|Sort LastWriteTime -Desc|Select -First 5 Name,@{N='AgeMin';E={[int]((Get-Date)-$_.LastWriteTime).TotalMinutes}}|ft|Out-String)"
    "}else{$r+=\"E:\\\\TLogBackups NOT FOUND`n\"};"
    "if(Test-Path 'E:\\\\Backups'){"
    "$b=Get-ChildItem 'E:\\\\Backups' -Filter '*.bak';"
    "$r+=\"Backups .bak count: $($b.Count)`n\";"
    "$r+=($b|Sort LastWriteTime -Desc|Select -First 5 Name,@{N='AgeMin';E={[int]((Get-Date)-$_.LastWriteTime).TotalMinutes}}|ft|Out-String)"
    "}else{$r+=\"E:\\\\Backups NOT FOUND`n\"};$r"
)
out, err, _ = ps("AgHost-1A", script, wait=12)
print(out or "(no output)"); print(err or "")

# ── SqlPoc ─────────────────────────────────────────────────────
header("SqlPoc: Databases & States")
out, err, _ = ps("SqlPoc", (
    "Invoke-Sqlcmd -ServerInstance '.' -Query \""
    "SELECT name, state_desc, recovery_model_desc "
    "FROM sys.databases ORDER BY name;\" -QueryTimeout 15 | Format-Table -AutoSize | Out-String"
))
print(out or "(no output)"); print(err or "")

header("SqlPoc: Disks")
out, err, _ = ps("SqlPoc", (
    "Get-Disk | Select-Object Number, OperationalStatus, IsReadOnly, "
    "@{N='SizeGB';E={[math]::Round($_.Size/1GB,0)}} | Format-Table | Out-String"
))
print(out or "(no output)"); print(err or "")

header("SqlPoc: Backup Directories")
out, err, _ = ps("SqlPoc", (
    "$r='';if(Test-Path 'E:\\\\Backups'){"
    "$b=Get-ChildItem 'E:\\\\Backups' -Filter '*.bak';"
    "$r+=\"Backups .bak: $($b.Count)`n\";"
    "$r+=($b|Sort LastWriteTime -Desc|Select -First 5|ft Name,LastWriteTime|Out-String)"
    "}else{$r+='E:\\\\Backups not found`n'};$r"
), wait=8)
print(out or "(no output)"); print(err or "")

print("\n=== Discovery Complete ===")
