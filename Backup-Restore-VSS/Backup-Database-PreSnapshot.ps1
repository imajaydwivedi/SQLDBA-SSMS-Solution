<#
.SYNOPSIS
    Backup-Database-PreSnapshot.ps1
    Take FULL database backups on AgHost-1A immediately before a VSS snapshot.

.DESCRIPTION
    Creates E:\Backups if missing, then runs BACKUP DATABASE WITH COMPRESSION for
    each database in $Databases.  Returns the backup timestamp so the caller can
    filter T-logs that were written after this backup.

    Run ON AgHost-1A (or via WinRM / qemu-agent from ryzen9).

.PARAMETER Databases
    Array of database names to back up. Default: CDCDemo, Db2, Facebook.
    StackOverflow2013 and DBA are excluded by default (size / admin-only).

.PARAMETER BackupDir
    Destination directory for .bak files. Default: E:\Backups.

.PARAMETER SqlInstance
    SQL Server instance name. Default: . (local default instance).

.EXAMPLE
    # All three databases
    .\Backup-Database-PreSnapshot.ps1

    # Specific databases
    .\Backup-Database-PreSnapshot.ps1 -Databases CDCDemo,Db2

    # With rename - same backup set, rename happens at restore time
    .\Backup-Database-PreSnapshot.ps1 -Databases CDCDemo
#>
param(
    [string[]] $Databases   = @('CDCDemo', 'Db2', 'Facebook'),
    [string]   $BackupDir   = 'E:\Backups',
    [string]   $SqlInstance = '.',
    [string]   $SqlUser     = 'sa',
    [string]   $SqlPassword = 'Pa$$w0rd'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TS = (Get-Date -Format 'yyyyMMdd_HHmmss')

function Write-Log { param([string]$m) Write-Host "$(Get-Date -f HH:mm:ss) $m" }
function Invoke-SQL { param([string]$q) 
    Invoke-Sqlcmd -ServerInstance $SqlInstance -Username $SqlUser -Password $SqlPassword `
        -Query $q -QueryTimeout 600 -ErrorAction Stop
}

# Ensure backup directory exists
Write-Log "Ensuring $BackupDir exists..."
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Force $BackupDir | Out-Null
    Write-Log "Created $BackupDir"
}
# Also ensure TLogBackups dir exists
if (-not (Test-Path 'E:\TLogBackups')) {
    New-Item -ItemType Directory -Force 'E:\TLogBackups' | Out-Null
    Write-Log "Created E:\TLogBackups"
}

# Verify databases are ONLINE and in FULL recovery
Write-Log "Verifying databases..."
foreach ($db in $Databases) {
    $info = Invoke-SQL "SELECT state_desc, recovery_model_desc FROM sys.databases WHERE name = '$db';"
    if (-not $info) { throw "Database '$db' not found on $SqlInstance" }
    if ($info.state_desc -ne 'ONLINE') { throw "[$db] is not ONLINE (state: $($info.state_desc))" }
    if ($info.recovery_model_desc -ne 'FULL') {
        Write-Log "[$db] Setting FULL recovery model..."
        Invoke-SQL "ALTER DATABASE [$db] SET RECOVERY FULL;"
    }
    Write-Log "[$db] OK - $($info.state_desc), $($info.recovery_model_desc)"
}

# Take FULL backups
$results = [ordered]@{}
foreach ($db in $Databases) {
    $bakFile = "$BackupDir\${db}_${TS}.bak"
    Write-Log "[$db] BACKUP DATABASE -> $bakFile ..."
    try {
        Invoke-SQL @"
BACKUP DATABASE [$db]
    TO DISK = N'$bakFile'
    WITH COMPRESSION, CHECKSUM, STATS = 10;
"@
        Write-Log "  [OK] $db -> $bakFile"
        $results[$db] = $bakFile
    } catch {
        Write-Error "  [FAIL] $db : $($_.Exception.Message)"
        $results[$db] = "FAILED"
    }
}

Write-Log ""
Write-Log "=== Pre-Snapshot Backup Complete ==="
Write-Log "Timestamp : $TS"
foreach ($db in $Databases) { Write-Log "  $db -> $($results[$db])" }
Write-Log ""
Write-Log "NEXT: Take VSS snapshot on ryzen9 immediately."
Write-Log "BackupTimestamp=$TS"   # parseable marker for orchestrator

# Return timestamp so bash orchestrator can capture it
$TS
