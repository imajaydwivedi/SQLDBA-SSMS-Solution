#!/usr/bin/env python3
"""Create the VSS-TLog-Backup-15min job on AgHost-1A."""
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from winrm_helper import push_file, run_ps, SA_PWD

SQL_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vss-tlog-job.sql")

print("=== Push vss-tlog-job.sql to AgHost-1A ===")
push_file("AgHost-1A", SQL_FILE, "C:\\Scripts\\vss-tlog-job.sql")

print("\n=== Enable xp_cmdshell ===")
out, err, rc = run_ps("AgHost-1A",
    f"Invoke-Sqlcmd -ServerInstance '.' -Username 'sa' -Password '{SA_PWD}' -Query \""
    "EXEC sp_configure 'show advanced options', 1; RECONFIGURE; "
    "EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;\"")
print(out or "(done)")

print("\n=== Execute vss-tlog-job.sql ===")
script = (
    "Invoke-Sqlcmd -InputFile 'C:\\Scripts\\vss-tlog-job.sql' "
    f"-ServerInstance '.' -Username 'sa' -Password '{SA_PWD}' "
    "-QueryTimeout 300 -ErrorAction Stop 2>&1 | Out-String"
)
out, err, rc = run_ps("AgHost-1A", script)
print(out or "(no output)")

print("\n=== Verify job state ===")
out, err, rc = run_ps("AgHost-1A",
    f"Invoke-Sqlcmd -ServerInstance '.' -Username 'sa' -Password '{SA_PWD}' -Query \""
    "SELECT j.name, j.enabled,"
    " (SELECT TOP 1 freq_subday_interval FROM msdb.dbo.sysschedules s"
    "  JOIN msdb.dbo.sysjobschedules js ON s.schedule_id=js.schedule_id"
    "  WHERE js.job_id=j.job_id) AS IntervalMin"
    " FROM msdb.dbo.sysjobs j"
    " WHERE j.name='VSS-TLog-Backup-15min';\""
    " | Format-Table -AutoSize | Out-String")
print(out or "(no output)")

print("=== Wait 45s for first T-log run and check files ===")
time.sleep(45)
out, err, rc = run_ps("AgHost-1A",
    "Get-ChildItem 'E:\\TLogBackups' -Filter '*.trn' | "
    "Sort LastWriteTime -Desc | Select -First 10 "
    "Name,LastWriteTime,@{N='AgeSec';E={[int]((Get-Date)-$_.LastWriteTime).TotalSeconds}} "
    "| ft -auto | Out-String")
print(out or "(empty)")

# Also show job history
print("=== Job run history (last 3) ===")
out, err, rc = run_ps("AgHost-1A",
    f"Invoke-Sqlcmd -ServerInstance '.' -Username 'sa' -Password '{SA_PWD}' -Query \""
    "SELECT TOP 5 run_date, run_time, run_duration, run_status, "
    "LEFT(message, 200) AS msg "
    "FROM msdb.dbo.sysjobhistory h "
    "JOIN msdb.dbo.sysjobs j ON h.job_id=j.job_id "
    "WHERE j.name='VSS-TLog-Backup-15min' "
    "ORDER BY run_date DESC, run_time DESC;\" | ft -auto | Out-String")
print(out or "(no history yet)")
