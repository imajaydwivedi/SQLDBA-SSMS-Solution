"""Diagnose and fix the sa login's default_database_name on SqlPoc.

If it points to a database that's RESTORING/OFFLINE, login for sa fails
at connect time with "Database 'X' cannot be opened." This script forces
it back to master so Invoke-Sqlcmd can at least authenticate before its
-Database parameter is honoured.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from winrm_helper import run_ps, SA_PWD

for host in ('SqlPoc', 'AgHost-1A'):
    ps = (
        f"Invoke-Sqlcmd -ServerInstance '.' -Username 'sa' -Password '{SA_PWD}' "
        f"-Database 'master' "
        f"-Query \"SELECT name, default_database_name FROM sys.server_principals "
        f"WHERE name='sa'\" -ErrorAction SilentlyContinue "
        f"| Format-Table -AutoSize | Out-String"
    )
    out, err, rc = run_ps(host, ps)
    print(f"--- {host} (before) rc={rc} ---")
    print(out.strip() if rc == 0 else err[:400])

    # Force sa back to master regardless
    ps_fix = (
        f"Invoke-Sqlcmd -ServerInstance '.' -Username 'sa' -Password '{SA_PWD}' "
        f"-Database 'master' "
        f"-Query \"ALTER LOGIN [sa] WITH DEFAULT_DATABASE = [master];\" "
        f"-ErrorAction Stop"
    )
    _, err, rc = run_ps(host, ps_fix)
    print(f"  ALTER LOGIN sa DEFAULT_DATABASE=master  rc={rc}",
          err[:200] if rc != 0 else "")

    out, _, _ = run_ps(host, ps)
    print(f"--- {host} (after) ---")
    print(out.strip())
