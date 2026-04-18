#!/usr/bin/env python3
"""Drop user DBs on SqlPoc and clear Backup/TLog dirs (between E2E runs)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from winrm_helper import run_ps, SA_PWD

ps = (
    "$dbs = @('CDCDemo','Db2','Facebook',"
    "'CDCDemo_Restored','Db2_Restored','Facebook_Restored');"
    "foreach ($db in $dbs) {"
    "  try {"
    f"    Invoke-Sqlcmd -ServerInstance '.' -Username 'sa' -Password '{SA_PWD}' "
    "      -Query \"IF DB_ID('$db') IS NOT NULL BEGIN "
    "               ALTER DATABASE [$db] SET OFFLINE WITH ROLLBACK IMMEDIATE; "
    "               DROP DATABASE [$db]; PRINT 'dropped $db'; END\" -ErrorAction Stop"
    "  } catch { Write-Host \"[SKIP] $db\" }"
    "}"
    "Remove-Item 'E:\\TLogBackups\\*' -Force -EA SilentlyContinue;"
    "Remove-Item 'E:\\Backups\\*' -Force -EA SilentlyContinue;"
    "Remove-Item 'E:\\MSSQL\\Data\\CDCDemo*' -Force -EA SilentlyContinue;"
    "Remove-Item 'E:\\MSSQL\\Data\\Db2*' -Force -EA SilentlyContinue;"
    "Remove-Item 'E:\\MSSQL\\Data\\Facebook*' -Force -EA SilentlyContinue;"
    f"Invoke-Sqlcmd -ServerInstance '.' -Username 'sa' -Password '{SA_PWD}' "
    "  -Query \"SELECT name FROM sys.databases ORDER BY name;\" | ft -auto | Out-String"
)
out, err, rc = run_ps('SqlPoc', ps)
print(out)
if err and 'Preparing modules' not in err:
    print('ERR:', err[:1500])
