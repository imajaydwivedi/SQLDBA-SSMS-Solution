"""Ad-hoc helper: drop the five benchmark DBs on SqlPoc so the next e2e run
starts from a clean slate. Safe to remove after benchmarking is done.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from winrm_helper import sqlcmd

DBS = ['CDCDemo', 'Db2', 'DBA', 'Facebook', 'StackOverflow2013']
for db in DBS:
    q = (
        f"IF DB_ID('{db}') IS NOT NULL BEGIN "
        f"IF (SELECT state_desc FROM sys.databases WHERE name='{db}') = 'ONLINE' "
        f"ALTER DATABASE [{db}] SET OFFLINE WITH ROLLBACK IMMEDIATE; "
        f"DROP DATABASE [{db}]; END"
    )
    out, err, rc = sqlcmd('SqlPoc', q)
    print(f"{db}: rc={rc}")

out, _, _ = sqlcmd('SqlPoc',
    "SELECT name, state_desc FROM sys.databases WHERE name IN "
    "('CDCDemo','Db2','DBA','Facebook','StackOverflow2013') ORDER BY name")
print('--- final ---')
print(out.strip() or '(all dropped)')
