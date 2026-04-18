"""Helper to re-run VssRestore.exe against an existing share and inspect state."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from winrm_helper import run_ps, sqlcmd

share = sys.argv[1] if len(sys.argv) > 1 else r"\\192.168.122.1\vss-transport\run1_Db2_20260418_202139"

print("--- Pre-state on SqlPoc ---")
out,_,_ = sqlcmd("SqlPoc", "SELECT name, state_desc, recovery_model_desc FROM sys.databases WHERE database_id > 4")
print(out)

ps = (
    r"$ErrorActionPreference='Stop';"
    r"$p = Start-Process -FilePath 'C:\Scripts\VssRestore\VssRestore.exe'"
    f" -ArgumentList @('--input','{share}')"
    r" -RedirectStandardOutput 'C:\Scripts\vr.out'"
    r" -RedirectStandardError  'C:\Scripts\vr.err'"
    r" -NoNewWindow -Wait -PassThru;"
    r"Write-Host ('exit_code=' + $p.ExitCode);"
    r"Write-Host '--- STDOUT ---';"
    r"Get-Content 'C:\Scripts\vr.out' -Raw;"
    r"Write-Host '--- STDERR ---';"
    r"Get-Content 'C:\Scripts\vr.err' -Raw"
)

print("--- Run VssRestore.exe on SqlPoc ---")
out, err, rc = run_ps("SqlPoc", ps)
print(out)
if err.strip():
    print("WINRM STDERR:", err[:400])

print("--- Post-state on SqlPoc ---")
out,_,_ = sqlcmd("SqlPoc", "SELECT name, state_desc, recovery_model_desc FROM sys.databases WHERE database_id > 4")
print(out)

print("--- Recent SQL Writer events on SqlPoc ---")
out,_,_ = run_ps("SqlPoc",
    "Get-WinEvent -LogName Application -MaxEvents 30 | "
    "? {$_.ProviderName -match 'VSS|SQLWriter' -and $_.TimeCreated -gt (Get-Date).AddMinutes(-5)} | "
    "Select TimeCreated, ProviderName, Id, LevelDisplayName, "
    "@{N='Msg';E={($_.Message -split \"`r`n\")[0..2] -join ' | '}} | "
    "Format-Table -AutoSize -Wrap | Out-String -Width 240")
print(out)
