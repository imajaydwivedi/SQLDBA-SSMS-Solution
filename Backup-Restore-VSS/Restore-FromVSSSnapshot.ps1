<#
.SYNOPSIS
    Restore-FromVSSSnapshot.ps1
    Restore databases on SqlPoc from the attached VSS snapshot disk (T:\).

.DESCRIPTION
    Copies .bak files from T:\Backups (snapshot disk) to local E:\Backups,
    then runs RESTORE DATABASE WITH NORECOVERY for each database.
    Supports database renaming via -RenameMap hashtable.
    Applies initial T-logs from \\AGHOST-1A\E$\TLogBackups up to current.

    Leaves databases in RESTORING state for ongoing Apply-TLogs.ps1 cycle.

.PARAMETER Databases
    Databases to restore. Must match .bak file prefixes on T:\Backups.

.PARAMETER RenameMap
    Optional hashtable mapping source DB name to target DB name.
    Example: @{CDCDemo='CDCDemo_Restored'}

.PARAMETER BackupTimestamp
    Timestamp string (yyyyMMdd_HHmmss) from the pre-snapshot .bak filename.
    T-logs with a filename timestamp BEFORE this are skipped.

.PARAMETER SnapshotDrive
    Drive letter where the snapshot qcow2 is mounted. Default: T.

.EXAMPLE
    # Full restore, no rename
    .\Restore-FromVSSSnapshot.ps1 -Databases CDCDemo,Db2,Facebook -BackupTimestamp 20260418_120000

    # With rename
    .\Restore-FromVSSSnapshot.ps1 -Databases CDCDemo -BackupTimestamp 20260418_120000 `
        -RenameMap @{CDCDemo='CDCDemo_Restored'}
#>
param(
    [string[]]    $Databases       = @('CDCDemo', 'Db2', 'Facebook'),
    [hashtable]   $RenameMap       = @{},
    [string]      $BackupTimestamp = '',
    [string]      $SnapshotDrive   = 'T',
    [string]      $LocalBackupDir  = 'E:\Backups',
    [string]      $LocalDataDir    = 'E:\MSSQL\Data',
    [string]      $SrcTLogDir      = '\\AGHOST-1A\E$\TLogBackups',
    [string]      $LocalTLogDir    = 'E:\TLogBackups',
    [string]      $SqlInstance     = '.',
    [string]      $SqlUser         = 'sa',
    [string]      $SqlPassword     = 'Pa$$w0rd',
    [string]      $SrcUser         = 'AgHost-1A\Administrator',
    [string]      $SrcPassword     = 'Pa$$w0rd'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log { param([string]$m) Write-Host "$(Get-Date -f HH:mm:ss) $m" }
function Invoke-SQL { param([string]$q, [int]$t = 600)
    Invoke-Sqlcmd -ServerInstance $SqlInstance -Username $SqlUser -Password $SqlPassword `
        -Query $q -QueryTimeout $t -ErrorAction Stop
}

New-Item -ItemType Directory -Force $LocalBackupDir | Out-Null
New-Item -ItemType Directory -Force $LocalDataDir   | Out-Null
New-Item -ItemType Directory -Force $LocalTLogDir   | Out-Null

# -- Step A: Copy .bak files from snapshot disk (T:\) ---------------------
$snapBackupDir = "${SnapshotDrive}:\Backups"
if (-not (Test-Path $snapBackupDir)) {
    throw "Snapshot backup dir not found: $snapBackupDir - is T:\ mounted?"
}
Write-Log "=== Copying .bak from ${SnapshotDrive}:\Backups -> $LocalBackupDir ==="
foreach ($db in $Databases) {
    $pattern = if ($BackupTimestamp) { "${db}_${BackupTimestamp}.bak" } else { "${db}_*.bak" }
    $baks = @(Get-ChildItem $snapBackupDir -Filter $pattern | Sort-Object LastWriteTime -Descending)
    if ($baks.Count -eq 0) { throw "No .bak found for [$db] in $snapBackupDir (pattern: $pattern)" }
    $src = $baks[0]
    Write-Log "  [$db] Copying $($src.Name) ..."
    Copy-Item $src.FullName (Join-Path $LocalBackupDir $src.Name) -Force
    Write-Log "  [$db] OK"
}

# -- Step B: RESTORE DATABASE WITH NORECOVERY -----------------------------
Write-Log "=== RESTORE DATABASE WITH NORECOVERY ==="
foreach ($db in $Databases) {
    $targetDb  = if ($RenameMap.ContainsKey($db)) { $RenameMap[$db] } else { $db }
    $pattern   = if ($BackupTimestamp) { "${db}_${BackupTimestamp}.bak" } else { "${db}_*.bak" }
    $bak       = (Get-ChildItem $LocalBackupDir -Filter $pattern | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    $mdf       = "$LocalDataDir\${targetDb}.mdf"
    $ldf       = "$LocalDataDir\${targetDb}_log.ldf"

    # Get logical file names
    $files = Invoke-SQL "RESTORE FILELISTONLY FROM DISK = N'$bak';" -t 60
    $dataLog = ($files | Where-Object Type -eq 'D' | Select-Object -First 1).LogicalName
    $logLog  = ($files | Where-Object Type -eq 'L' | Select-Object -First 1).LogicalName

    Write-Log "[$db] -> [$targetDb]  bak=$bak"
    Write-Log "  Logical: data=$dataLog log=$logLog"
    try {
        Invoke-SQL @"
RESTORE DATABASE [$targetDb]
    FROM DISK = N'$bak'
    WITH NORECOVERY,
         MOVE N'$dataLog' TO N'$mdf',
         MOVE N'$logLog'  TO N'$ldf',
         STATS = 10, REPLACE;
"@ -t 900
        Write-Log "  [OK] $targetDb -> RESTORING"
    } catch {
        Write-Error "  [FAIL] ${targetDb}: $($_.Exception.Message)"; continue
    }
}

# Step C: Initial T-log catch-up
Write-Log "=== Applying initial T-logs WITH NORECOVERY ==="
# Copy new T-logs from AgHost-1A (use credentialed PSDrive for workgroup hosts)
try {
    $srcCred = New-Object System.Management.Automation.PSCredential(
        $SrcUser, (ConvertTo-SecureString $SrcPassword -AsPlainText -Force))
    Get-PSDrive -Name 'TLogSrc' -ErrorAction SilentlyContinue | Remove-PSDrive
    New-PSDrive -Name 'TLogSrc' -PSProvider FileSystem -Root $SrcTLogDir -Credential $srcCred -Scope Script | Out-Null
    $newTrns = @(Get-ChildItem 'TLogSrc:\' -Filter '*.trn' -ErrorAction Stop |
               Where-Object { -not (Test-Path (Join-Path $LocalTLogDir $_.Name)) })
    foreach ($f in ($newTrns | Sort-Object Name)) {
        Copy-Item $f.FullName $LocalTLogDir -Force
        Write-Log "  Copied: $($f.Name)"
    }
} catch { Write-Warning "Could not copy from AgHost-1A: $_" }

foreach ($db in $Databases) {
    $targetDb = if ($RenameMap.ContainsKey($db)) { $RenameMap[$db] } else { $db }
    $tlogFiles = @(Get-ChildItem $LocalTLogDir -Filter '*.trn' |
                 Where-Object { $_.Name.ToLower().StartsWith($db.ToLower() + '_') } |
                 Where-Object { (-not $BackupTimestamp) -or ($_.Name -gt "${db}_$BackupTimestamp") } |
                 Sort-Object Name)

    Write-Log "[$db->$targetDb] Applying $($tlogFiles.Count) T-log(s)..."
    foreach ($tlog in $tlogFiles) {
        try {
            Invoke-SQL "RESTORE LOG [$targetDb] FROM DISK = N'$($tlog.FullName)' WITH NORECOVERY, STATS=10;" -t 300
            Write-Log "  [OK] $($tlog.Name)"
        } catch {
            Write-Warning "  [STOP] $($tlog.Name): $($_.Exception.Message)"; break
        }
    }
}

# Seed state file so Apply-TLogs.ps1 skips pre-backup T-logs on its first run
$stateFile = Join-Path $LocalTLogDir 'applied_state.json'
$state = [ordered]@{}
foreach ($db in $Databases) {
    # Lower-bound cutoff: anything <= "${db}_${BackupTimestamp}" is skipped
    $state[$db] = if ($BackupTimestamp) { "${db}_${BackupTimestamp}" } else { '' }
}
$state | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8
Write-Log "Seeded state file: $stateFile"

# Verify
Write-Log "=== Verifying DB states ==="
Invoke-SQL "SELECT name, state_desc FROM sys.databases WHERE name NOT IN ('master','model','msdb','tempdb') ORDER BY name;" |
    Format-Table | Out-String | Write-Host
Write-Log "Done. Databases should show RESTORING."
