"""Discovery before pure-VSS E2E runs."""
import sys, os, subprocess
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from winrm_helper import run_ps, sqlcmd

print("=" * 60); print("AgHost-1A : user DBs and recovery model"); print("=" * 60)
out,_,_ = sqlcmd("AgHost-1A",
    "SELECT name, recovery_model_desc, state_desc FROM sys.databases "
    "WHERE database_id > 4 ORDER BY name")
print(out)

print("=" * 60); print("AgHost-1A : file paths for Db2"); print("=" * 60)
out,_,_ = sqlcmd("AgHost-1A",
    "SELECT d.name AS db, mf.name AS logical, mf.physical_name "
    "FROM sys.databases d JOIN sys.master_files mf ON d.database_id=mf.database_id "
    "WHERE d.name='Db2'")
print(out)

print("=" * 60); print("AgHost-1A : T-log job existence + last run"); print("=" * 60)
out,_,_ = sqlcmd("AgHost-1A",
    "SELECT TOP 5 j.name, h.run_date, h.run_time, h.run_status "
    "FROM msdb.dbo.sysjobs j LEFT JOIN msdb.dbo.sysjobhistory h ON j.job_id=h.job_id "
    "WHERE j.name LIKE '%log%' OR j.name LIKE '%VSS%' ORDER BY h.run_date DESC, h.run_time DESC")
print(out)

print("=" * 60); print("SqlPoc : existing DBs (check for Db2 collision)"); print("=" * 60)
out,_,_ = sqlcmd("SqlPoc",
    "SELECT name, recovery_model_desc, state_desc FROM sys.databases "
    "WHERE database_id > 4 ORDER BY name")
print(out)

print("=" * 60); print("SqlPoc : VSS Writer status"); print("=" * 60)
out,_,_ = run_ps("SqlPoc", "vssadmin list writers | Select-String -Pattern 'Writer name|State'")
print(out)

print("=" * 60); print("AgHost-1A : VSS Writer status"); print("=" * 60)
out,_,_ = run_ps("AgHost-1A", "vssadmin list writers | Select-String -Pattern 'Writer name|State'")
print(out)

print("=" * 60); print("ryzen9 : Samba share status"); print("=" * 60)
for cmd in [
    ["ls", "-la", "/hyperactive/vss-transport/"],
    ["sudo", "smbstatus", "--shares"],
    ["grep", "-A4", "vss-transport", "/etc/samba/smb.conf"],
]:
    print(">>>", " ".join(cmd))
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
    print(r.stdout.strip() if r.stdout else r.stderr.strip())
    print()
