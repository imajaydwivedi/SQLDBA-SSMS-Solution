<#
.SYNOPSIS
    Apply-TLogs.ps1 - Continuous T-log apply for VSS warm-standby on SqlPoc.

.DESCRIPTION
    Copies only NEW .trn files from AgHost-1A's E:\TLogBackups\ (via SMB admin share)
    to SqlPoc's local E:\TLogBackups\, then applies them via RESTORE LOG WITH NORECOVERY.
    Tracks the last-applied T-log per database in a JSON state file so re-runs are safe.

    Schedule  : Windows Task Scheduler - every 15 minutes
    Run on    : SqlPoc (192.168.122.192) as domain service account

.NOTES
    Databases : CDCDemo, Db2, DBA, Facebook (set $Databases below)
    Source    : \\AGHOST-1A\E$\TLogBackups   (SMB admin share - domain auth)
    State file: E:\TLogBackups\applied_state.json
    Log file  : E:\TLogBackups\apply_tlog.log
#>

param(
    [string[]] $Databases  = @('CDCDemo','Db2','Facebook'),
    [hashtable]$RenameMap  = @{},     # e.g. @{CDCDemo='CDCDemo_Restored'}
    [string]   $SrcTLogDir = '\\AGHOST-1A\E$\TLogBackups',
    [string]   $DstTLogDir = 'E:\TLogBackups',
    [string]   $StateFile  = 'E:\TLogBackups\applied_state.json',
    [string]   $LogFile    = 'E:\TLogBackups\apply_tlog.log',
    [string]   $Instance   = '.',
    [string]   $SqlUser    = 'sa',
    [string]   $SqlPassword= 'Pa$$w0rd',
    [string]   $SrcUser    = 'AgHost-1A\Administrator',
    [string]   $SrcPassword= 'Pa$$w0rd'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$msg)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

# Ensure local T-log directory exists
New-Item -ItemType Directory -Force $DstTLogDir | Out-Null

# Load state (last applied .trn name per DB, empty string = nothing applied yet)
$State = [ordered]@{}
if (Test-Path $StateFile) {
    $loaded = Get-Content $StateFile -Raw | ConvertFrom-Json
    foreach ($db in $Databases) {
        $State[$db] = if ($null -ne $loaded.$db) { $loaded.$db } else { '' }
    }
} else {
    foreach ($db in $Databases) { $State[$db] = '' }
}

Write-Log "=== Apply-TLogs cycle start ==="

# Mount source SMB share with explicit credentials (workgroup -> remote local admin)
$srcCred = New-Object System.Management.Automation.PSCredential(
    $SrcUser, (ConvertTo-SecureString $SrcPassword -AsPlainText -Force))
Get-PSDrive -Name 'TLogSrc' -ErrorAction SilentlyContinue | Remove-PSDrive
New-PSDrive -Name 'TLogSrc' -PSProvider FileSystem -Root $SrcTLogDir -Credential $srcCred -Scope Script | Out-Null

# Step 1: Copy only NEW .trn files from AgHost-1A
try {
    $srcFiles = @(Get-ChildItem 'TLogSrc:\' -Filter '*.trn' -ErrorAction Stop)
    $newFiles  = @($srcFiles | Where-Object { -not (Test-Path (Join-Path $DstTLogDir $_.Name)) })
    if ($newFiles.Count -gt 0) {
        Write-Log "Copying $($newFiles.Count) new T-log(s) from AgHost-1A..."
        foreach ($f in ($newFiles | Sort-Object Name)) {
            Copy-Item $f.FullName (Join-Path $DstTLogDir $f.Name) -Force
            Write-Log "  Copied: $($f.Name)"
        }
    } else {
        Write-Log "No new T-logs to copy."
    }
} catch {
    Write-Log "ERROR accessing AgHost-1A share: $_"
    exit 1
}

# -- Step 2: Apply new T-logs per DB - NORECOVERY only (no STOPAT) ---------
foreach ($db in $Databases) {
    $targetDb    = if ($RenameMap.ContainsKey($db)) { $RenameMap[$db] } else { $db }
    $lastApplied = $State[$db]

    # StartsWith filter using SOURCE db name; apply to TARGET db name
    $tlogFiles = @(Get-ChildItem $DstTLogDir -Filter '*.trn' |
                 Where-Object { $_.Name.ToLower().StartsWith($db.ToLower() + '_') } |
                 Where-Object { $_.Name -gt $lastApplied } |
                 Sort-Object Name)

    if ($tlogFiles.Count -eq 0) {
        Write-Log "[$db->$targetDb] No new T-logs to apply."
        continue
    }

    Write-Log "[$db->$targetDb] Applying $($tlogFiles.Count) T-log(s)..."

    foreach ($tlog in $tlogFiles) {
        try {
            Invoke-Sqlcmd -ServerInstance $Instance -Username $SqlUser -Password $SqlPassword `
                -QueryTimeout 300 -ErrorAction Stop `
                -Query "RESTORE LOG [$targetDb] FROM DISK = N'$($tlog.FullName)' WITH NORECOVERY, STATS = 10;"
            $State[$db] = $tlog.Name
            Write-Log "  [OK] $targetDb <- $($tlog.Name)"
        } catch {
            Write-Log "  [FAIL] $targetDb <- $($tlog.Name): $($_.Exception.Message)"
            Write-Log "  [STOP] Halting $db chain - check state before next run."
            break
        }
    }
}

# -- Step 3: Persist state -------------------------------------------------
$State | ConvertTo-Json | Set-Content $StateFile
Write-Log "State saved. Cycle complete."
