"""
Multi-DB Pure-VSS E2E runner.

Usage:  python3 e2e_run_multi.py <label> <db1,db2,...> <with-tlog|no-tlog>
Example:
    python3 e2e_run_multi.py all_tlog  CDCDemo,Db2,DBA,Facebook  with-tlog
    python3 e2e_run_multi.py pair_notl DBA,Facebook              no-tlog
"""
import sys, os, time, datetime, subprocess, textwrap
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, ROOT)
from winrm_helper import run_ps, sqlcmd

label   = sys.argv[1]
dbs     = [d.strip() for d in sys.argv[2].split(",") if d.strip()]
tlog    = sys.argv[3].lower() == "with-tlog"
ts      = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
share   = r"\\192.168.122.1\vss-transport"
folder  = f"{label}_{ts}"
out_unc = f"{share}\\{folder}"
out_lin = f"/hyperactive/vss-transport/{folder}"

def banner(s):
    print(); print("#" * 78); print("# " + s); print("#" * 78)
def section(s):
    print(); print("-" * 78); print(s); print("-" * 78)

banner(f"E2E-MULTI  label={label}  dbs={dbs}  tlog={tlog}  ts={ts}")
print(f"share  : {out_unc}")
print(f"linux  : {out_lin}")

section("0. Drop each target DB on SqlPoc (online or restoring)")
for db in dbs:
    out,_,_ = run_ps("SqlPoc", f"""
$db='{db}'
Invoke-Sqlcmd -ServerInstance '.' -Query @"
IF DB_ID('$db') IS NOT NULL
BEGIN
    DECLARE @s SYSNAME = (SELECT state_desc FROM sys.databases WHERE name='$db');
    IF @s = N'ONLINE'
        ALTER DATABASE [$db] SET OFFLINE WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$db];
END
"@
'{db} -> DB_ID=' + [string]((Invoke-Sqlcmd -ServerInstance '.' -Query "SELECT DB_ID('$db') AS id").id)
""")
    print(out.strip())
subprocess.run(["rm", "-rf", out_lin], check=False)
os.makedirs(out_lin, exist_ok=True)
subprocess.run(["chmod", "777", out_lin], check=False)

section("1. AgHost-1A: source state for selected DBs")
qlist = ",".join(f"'{d}'" for d in dbs)
out,_,_ = sqlcmd("AgHost-1A",
    f"SELECT name, state_desc, recovery_model_desc "
    f"FROM sys.databases WHERE name IN ({qlist}) ORDER BY name")
print(out)

section("2. VssBackup.exe --databases " + ",".join(dbs))
script = textwrap.dedent(f"""
$out = 'C:\\Scripts\\VssBackup_{label}_out.txt'
$err = 'C:\\Scripts\\VssBackup_{label}_err.txt'
Remove-Item $out,$err -EA SilentlyContinue
$t0 = Get-Date
$p = Start-Process -FilePath 'C:\\Scripts\\VssBackup\\VssBackup.exe' `
     -ArgumentList '--databases','{",".join(dbs)}','--output','{out_unc}' `
     -NoNewWindow -Wait -PassThru `
     -RedirectStandardOutput $out -RedirectStandardError $err
$dt = (Get-Date) - $t0
"duration_seconds=$([int]$dt.TotalSeconds)"
"exit_code=$($p.ExitCode)"
'--- STDOUT ---'
Get-Content $out
'--- STDERR ---'
Get-Content $err
""")
t0 = time.time()
out,err,rc = run_ps("AgHost-1A", script, timeout=3600)
print(f"[orchestrator wall time: {time.time()-t0:.1f}s]")
print(out)
if err.strip(): print("WINRM STDERR:", err.strip()[:500])

section("3. Share listing after backup")
r = subprocess.run(["ls","-la",out_lin], capture_output=True, text=True); print(r.stdout)
for db in dbs:
    p = os.path.join(out_lin, db)
    if os.path.isdir(p):
        r = subprocess.run(["du","-sh",p], capture_output=True, text=True)
        print(r.stdout.strip())

section("4. VssRestore.exe --input " + out_unc)
script = textwrap.dedent(f"""
$out = 'C:\\Scripts\\VssRestore_{label}_out.txt'
$err = 'C:\\Scripts\\VssRestore_{label}_err.txt'
Remove-Item $out,$err -EA SilentlyContinue
$t0 = Get-Date
$p = Start-Process -FilePath 'C:\\Scripts\\VssRestore\\VssRestore.exe' `
     -ArgumentList '--input','{out_unc}' `
     -NoNewWindow -Wait -PassThru `
     -RedirectStandardOutput $out -RedirectStandardError $err
$dt = (Get-Date) - $t0
"duration_seconds=$([int]$dt.TotalSeconds)"
"exit_code=$($p.ExitCode)"
'--- STDOUT ---'
Get-Content $out
'--- STDERR ---'
Get-Content $err
""")
t0 = time.time()
out,err,rc = run_ps("SqlPoc", script, timeout=3600)
print(f"[orchestrator wall time: {time.time()-t0:.1f}s]")
print(out)
if err.strip(): print("WINRM STDERR:", err.strip()[:500])

section("5. SqlPoc: post-restore state for each selected DB")
out,_,_ = sqlcmd("SqlPoc",
    f"SELECT name, state_desc, recovery_model_desc "
    f"FROM sys.databases WHERE name IN ({qlist}) ORDER BY name")
print(out)

if tlog:
    for db in dbs:
        section(f"6.{db}. T-log chain verify for {db}")
        r = subprocess.run(
            ["python3", f"{HERE}/verify_tlog_chain.py", db],
            capture_output=True, text=True, timeout=600)
        print(r.stdout)
        if r.returncode != 0:
            print(f"*** verify_tlog_chain FAILED for {db} (rc={r.returncode}) ***")
            print(r.stderr[:600])
else:
    section("6. T-log verification SKIPPED (no-tlog mode)")

print("\n" + "=" * 78)
print(f"E2E-MULTI {label} complete.  Share kept at {out_unc}")
print("=" * 78)
