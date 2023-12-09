# Get-contsoLogWalkBackupRestore
$SourceServer = 'source01';
$SourceDbName = 'db01';
$DestinationServer = 'destination01';
$DestinationDbName = 'db02';

if($DestinationDbName -eq $null) {$DestinationDbName = $SourceDbName};
$commentHeader = if ($SourceDbName -eq $DestinationDbName) {"[$SourceServer]"} else {"[$SourceDbName] => [$DestinationDbName]"};

# Get Last backups
$backupHistory = Get-DbaBackupHistory -SqlInstance $SourceServer -Database $SourceDbName -Last;
# Get backup History into excel file
#$backupHistory | Select-Object * | Export-Excel -Path "C:\TEMP\$SourceServer-BackupInfo.xlsx" -WorkSheetname $SourceDbName;

$fullBkp = $backupHistory | Where-Object {$_.Type -eq 'Full'};
$diffBkp = $backupHistory | Where-Object {$_.Type -eq 'Differential'};
$logBkps = $backupHistory | Where-Object {$_.Type -eq 'Log'} | Sort-Object -Property Start;

$sqlText = @"

/* Script to restore [$SourceDbName] from server [$SourceServer] as
        [$DestinationDbName] database on [$DestinationServer]
*/

"@;

# Create TSQL Code for Full Restore
$networkPath = "\\$SourceServer\" + ($($fullBkp.Path) -replace ':\\','$\');
$sqlText = @"
-- $commentHeader - Full restore of $($fullBkp.TotalSize) total size from backup of '$($fullBkp.Start)'
RESTORE DATABASE [$DestinationDbName] FROM  DISK = N'$networkPath'
    WITH NORECOVERY
         ,STATS = 5
         --,REPLACE
"@;

# Add WITH MOVE option in Full Restore
foreach ($file in $fullBkp.FileList)
{
    $sqlText += @"

         --,MOVE N'$($file.LogicalName)' TO N'$($file.PhysicalName)'
"@;
}

$sqlText += @"

GO
"@;

$sqlText += @"

if (@@ERROR <> 0)
	set noexec on;
GO
"@;

# Add Differential Backup
$networkPath = "\\$SourceServer\" + ($($diffBkp.Path) -replace ':\\','$\');
$sqlText += @"


-- $commentHeader - Differential restore of $($diffBkp.TotalSize) total size from backup of '$($diffBkp.Start)'
RESTORE DATABASE [$DestinationDbName] FROM  DISK = N'$networkPath'
    WITH NORECOVERY
         ,STATS = 5
GO
"@;

$sqlText += @"

if (@@ERROR <> 0)
	set noexec on;
GO
"@;

# Add TLog backup
foreach($logFile in $logBkps)
{
    $networkPath = "\\$SourceServer\" + ($($logFile.Path) -replace ':\\','$\');
    $sqlText += @"


-- $commentHeader - Log restore of $($logFile.TotalSize) total size from backup of '$($logFile.Start)'
RESTORE LOG [$DestinationDbName] FROM  DISK = N'$networkPath'
    WITH NORECOVERY
         ,STATS = 10
         --,STANDBY = N'F:\dump\$($DestinationDbName)_undo.dat'
GO
"@;

    $sqlText += @"

if (@@ERROR <> 0)
	set noexec on;
GO
"@;
}


$LastFileApplied = if($($logFile.Path) -match ".+\\(?'fileName'\w+\.[a-zA-Z]{1,3})") {$Matches['fileName']} else {$null};
$sqlText += @"


use master
go
Declare @dbname sysname
set @dbname = '$DestinationDbName'
Update dbo.DBALastFileApplied 
	set PointerResetFile = '$LastFileApplied' 
		,LastFileApplied = '$LastFileApplied' 
where dbname = @dbname;
GO

select * from dbo.DBALastFileApplied where dbname = '$DestinationDbName'
GO
"@;

$sqlText += @"

if (@@ERROR <> 0)
	set noexec off;
GO

SELECT 'Execute Log Walk job Now' as [Action];
"@;


Clear-Host;
#Write-Host $sqlText;
$scriptOutFile = "TSQL_Restore_$($DestinationServer)_$($DestinationDbName) __$((Get-Date -Format 'dd-MMM-yyyy HH.mm tt')).sql";
Write-Host "Saving the generated TSQL code to 'c:\temp\$scriptOutFile'" -ForegroundColor Green;
Write-Host "Opening the generated TSQL code file..." -ForegroundColor Yellow;
$sqlText | Out-File -FilePath "c:\temp\$scriptOutFile";
notepad "c:\temp\$scriptOutFile";

