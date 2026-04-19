"""Read the _vss_marker row for all five benchmark DBs on SqlPoc.

Also hunt for objects in CDCDemo that reference 'DBA' in their definitions,
which would explain the cross-DB "Database 'DBA' cannot be opened." error.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from winrm_helper import sqlcmd

print("=== DB states ===")
print(sqlcmd('SqlPoc',
    "SELECT name, state_desc FROM sys.databases WHERE name IN "
    "('CDCDemo','Db2','DBA','Facebook','StackOverflow2013') ORDER BY name")[0])

for db in ('CDCDemo', 'Db2', 'DBA', 'Facebook', 'StackOverflow2013'):
    out, err, rc = sqlcmd('SqlPoc',
        f"IF DB_ID('{db}') IS NOT NULL "
        f"SELECT '{db}' AS db, TOP 1 note, ts FROM [{db}].dbo._vss_marker "
        f"ORDER BY ts DESC")
    print(f"--- marker read {db} rc={rc} ---")
    print(out.strip() if rc == 0 else err[:500])

# Simpler: iterate explicitly
for db in ('CDCDemo', 'Db2', 'DBA', 'Facebook', 'StackOverflow2013'):
    out, err, rc = sqlcmd('SqlPoc',
        f"SELECT TOP 1 note, ts FROM [{db}].dbo._vss_marker ORDER BY ts DESC")
    print(f"--- {db} latest marker: rc={rc} ---")
    print((out.strip() or '(empty)') if rc == 0 else f"ERR: {err[:300]}")

print("=== CDCDemo objects referencing 'DBA' in definition ===")
out, err, rc = sqlcmd('SqlPoc',
    "SELECT o.name, o.type_desc "
    "FROM CDCDemo.sys.sql_modules m "
    "JOIN CDCDemo.sys.objects o ON m.object_id = o.object_id "
    "WHERE m.definition LIKE '%DBA.%' OR m.definition LIKE '%[DBA]%'")
print(out.strip() if rc == 0 else err[:500])
