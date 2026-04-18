"""
Pure-VSS E2E runner: one DB through VssBackup -> Samba -> VssRestore.
Captures every command + output so the doc can quote exact results.

Usage:   python3 e2e_run.py <db> <run_label>
Example: python3 e2e_run.py Db2 run1
"""
import sys, os, time, datetime, subprocess, textwrap
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from winrm_helper import run_ps, sqlcmd

db    = sys.argv[1] if len(sys.argv) > 1 else "Db2"
label = sys.argv[2] if len(sys.argv) > 2 else "run1"
ts    = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
share = r"\\192.168.122.1\vss-transport"
folder = f"{label}_{db}_{ts}"
out_unc = f"{share}\\{folder}"
out_lin = f"/hyperactive/vss-transport/{folder}"

def banner(s):
    print()
    print("#" * 72)
    print("# " + s)
    print("#" * 72)

def section(s):
    print()
    print("-" * 72)
    print(s)
    print("-" * 72)

banner(f"PURE-VSS E2E  db={db}  label={label}  ts={ts}")
print(f"share  : {out_unc}")
print(f"linux  : {out_lin}")

section("0. Clean SqlPoc: drop target DB if present; clean old share folder")
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
'DB_ID after drop: ' + (Invoke-Sqlcmd -ServerInstance '.' -Query "SELECT DB_ID('$db') AS id").id
""")
print(out)
subprocess.run(["rm", "-rf", out_lin], check=False)
os.makedirs(out_lin, exist_ok=True)
subprocess.run(["chmod", "777", out_lin], check=False)

section("1. Backup state capture (AgHost-1A: LSN before VSS snapshot)")
out,_,_ = sqlcmd("AgHost-1A",
    f"SELECT name, recovery_model_desc, state_desc, "
    f"(SELECT TOP 1 redo_start_lsn FROM master.sys.master_files mf "
    f"WHERE mf.database_id=d.database_id) AS lsn_hint "
    f"FROM sys.databases d WHERE name='{db}'")
print(out)

section("2. Run VssBackup.exe on AgHost-1A")
script = textwrap.dedent(f"""
$out = 'C:\\Scripts\\VssBackup_{label}_out.txt'
$err = 'C:\\Scripts\\VssBackup_{label}_err.txt'
Remove-Item $out,$err -EA SilentlyContinue
$t0 = Get-Date
$p = Start-Process -FilePath 'C:\\Scripts\\VssBackup\\VssBackup.exe' `
     -ArgumentList '--databases','{db}','--output','{out_unc}' `
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
out, err, rc = run_ps("AgHost-1A", script)
print(f"[wall time from orchestrator: {time.time()-t0:.1f}s]")
print(out)
if err.strip(): print("WINRM STDERR:", err.strip()[:500])

section("3. Share contents after backup")
r = subprocess.run(["ls", "-la", out_lin], capture_output=True, text=True)
print(r.stdout)
for sub in ["", "writer_metadata"]:
    p = os.path.join(out_lin, sub) if sub else out_lin
    if os.path.isdir(p):
        r = subprocess.run(["ls", "-la", p], capture_output=True, text=True)
        print(f"--- {p} ---"); print(r.stdout)
db_dir = os.path.join(out_lin, db)
if os.path.isdir(db_dir):
    r = subprocess.run(["ls", "-la", db_dir], capture_output=True, text=True)
    print(f"--- {db_dir} ---"); print(r.stdout)

section("4. Run VssRestore.exe on SqlPoc")
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
out, err, rc = run_ps("SqlPoc", script)
print(f"[wall time from orchestrator: {time.time()-t0:.1f}s]")
print(out)
if err.strip(): print("WINRM STDERR:", err.strip()[:500])

section("5. Post-restore DB state on SqlPoc")
out,_,_ = sqlcmd("SqlPoc",
    f"SELECT name, state_desc, recovery_model_desc FROM sys.databases "
    f"WHERE name='{db}'")
print(out)
out,_,_ = sqlcmd("SqlPoc",
    f"SELECT mf.name AS logical, mf.physical_name, mf.state_desc "
    f"FROM sys.master_files mf JOIN sys.databases d ON mf.database_id=d.database_id "
    f"WHERE d.name='{db}'")
print(out)

print()
print("=" * 72)
print(f"E2E {label} complete.  Share kept at {out_unc}")
print("=" * 72)
