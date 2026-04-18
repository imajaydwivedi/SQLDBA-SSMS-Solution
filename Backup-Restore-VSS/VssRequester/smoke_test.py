import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from winrm_helper import run_ps

script_tpl = r"""
$out = 'C:\Scripts\smoke_out.txt'; $err = 'C:\Scripts\smoke_err.txt'
Remove-Item $out,$err -EA SilentlyContinue
$p = Start-Process -FilePath '__EXE__' -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
'--- STDOUT ---'
Get-Content $out
'--- STDERR ---'
Get-Content $err
'--- EXITCODE ---'
$p.ExitCode
"""

for host, exe in [
    ("AgHost-1A", r"C:\Scripts\VssBackup\VssBackup.exe"),
    ("SqlPoc",    r"C:\Scripts\VssRestore\VssRestore.exe"),
]:
    s = script_tpl.replace("__EXE__", exe)
    out, err, rc = run_ps(host, s)
    print(f"=== {host}  {exe} ===")
    print(out)
    if err.strip():
        print("winrm stderr:", err.strip()[:300])
    print("winrm rc:", rc)
    print()
