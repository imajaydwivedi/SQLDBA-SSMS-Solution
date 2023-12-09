Remove-Variable * -ErrorAction SilentlyContinue; $Error.Clear()

#Parameters
[string]$Path = 'C:\Users\Public\Documents\ProjectWork\sql2019upgrade\'
[string]$DistributorPrimary = 'DistributorPrimarySqlInstance'
[string]$DistributorSecondary = 'DistributorSecondarySqlInstance'
[string]$DistributionDb = 'distribution'
[string]$DistributionAgName = 'dist_ag'
[string]$DistributorListener = 'dist_listener'
[string]$DistributorListenerIp = 'Ipv4Address'
[string]$ReplWorkingDirectory = '\\DistributorNode\share\'

# Derived variables
$dtmm = get-date -f 'yyyyMMdd-HHmmsss'
$filePath = Join-Path $Path "setup-repl-remote-distributor-ag $dtmm.sql"

@"
/* ****** PARAMETERS *****************
`$Path = $Path
`$DistributorPrimary = $DistributorPrimary
`$DistributorSecondary = $DistributorSecondary
`$DistributionDb = $DistributionDb
`$DistributionAgName = $DistributionAgName
`$DistributorListener = $DistributorListener
`$DistributorListenerIp = $DistributorListenerIp
`$ReplWorkingDirectory = $ReplWorkingDirectory
*/

"@ | Out-File -FilePath $filePath -Append -Encoding ascii

# Step 01: Configure the Distribution DB nodes (AG Replicas) to act as a distributor
@"
-- Step1 - Configure the Distribution DB nodes (AG Replicas) to act as a distributor
:Connect $DistributorPrimary
sp_adddistributor @distributor = @@ServerName, @password = 'Pass@word1'
Go
:Connect $DistributorSecondary
sp_adddistributor @distributor = @@ServerName, @password = 'Pass@word1'
Go

"@ | Out-File -FilePath $filePath -Append -Encoding ascii

# Step 02: Configure the Distribution Database
$fullBackupPath = Join-Path $ReplWorkingDirectory "$DistributionDb`_FULL_$dtmm.bak"
$logBackupPath = Join-Path $ReplWorkingDirectory "$DistributionDb`_LOG_$dtmm.trn"

@"
-- Step2 - Configure the Distribution Database
:Connect $DistributorPrimary
USE master
EXEC sp_adddistributiondb @database = '$DistributionDb', @security_mode = 1;
GO
Alter Database [$DistributionDb] Set Recovery Full
Go
Backup Database [$DistributionDb] to Disk = '$fullBackupPath'
Go
Backup LOG [$DistributionDb] to Disk = '$logBackupPath'
Go

"@ | Out-File -FilePath $filePath -Append -Encoding ascii

# Step 03: Restore the Distribution Database
$resultSourceFilePath = Invoke-Sqlcmd -ServerInstance $DistributorPrimary -Database $DistributionDb -Query "select @@servername as srv_name, SERVERPROPERTY('InstanceName') as instance_base_name, name as logical_name, type_desc, physical_name from sys.database_files"
$resultDestinationInstanceBaseName = Invoke-Sqlcmd -ServerInstance $DistributorSecondary -Query "select SERVERPROPERTY('InstanceName') as instance_base_name"
$dataFilePathSource = $resultSourceFilePath | Where-Object {$_.type_desc -eq 'ROWS'}
$logFilePathSource = $resultSourceFilePath | Where-Object {$_.type_desc -eq 'LOG'}
if($resultSourceFilePath[0].instance_base_name -ne $resultDestinationInstanceBaseName.instance_base_name) {
    $dataFilePathDestination = ($dataFilePathSource.physical_name -replace $resultSourceFilePath[0].instance_base_name,$resultDestinationInstanceBaseName.instance_base_name)
    $logFilePathDestination = ($logFilePathSource.physical_name -replace $resultSourceFilePath[0].instance_base_name,$resultDestinationInstanceBaseName.instance_base_name)
}
else {
    $dataFilePathDestination = $dataFilePathSource.physical_name
    $logFilePathDestination = $logFilePathSource.physical_name
}

@"
-- On Distributor (Secondary Replica), restore Distribution database
:CONNECT $DistributorSecondary
use master
GO
RESTORE Database [$DistributionDb] FROM Disk = '$fullBackupPath' WITH NORECOVERY, STATS = 5
		,move '$DistributionDb' to '$dataFilePathDestination'
		,move '$DistributionDb`_log' to '$logFilePathDestination'
Go
RESTORE LOG [$DistributionDb] FROM Disk = '$logBackupPath' WITH NORECOVERY,STATS = 5
Go

"@ | Out-File -FilePath $filePath -Append -Encoding ascii


# Step 04: Join Distribution database to AG
@"
:Connect $DistributorPrimary
USE [master]
GO

ALTER AVAILABILITY GROUP [$DistributionAgName]
MODIFY REPLICA ON N'$DistributorSecondary' WITH (SEEDING_MODE = MANUAL)
GO

ALTER AVAILABILITY GROUP [$DistributionAgName]
ADD DATABASE [$DistributionDb];
GO


:Connect $DistributorSecondary
ALTER DATABASE [$DistributionDb] SET HADR AVAILABILITY GROUP = [$DistributionAgName];
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii


# Step 05: Enable Secondary replica as Distributor
@"
-- STEP 5 - Enable Secondary replica as Distributor
    -- Ensure 'Readable Secondary' attribute is set to 'Yes' on both replicas
:CONNECT $DistributorSecondary
EXEC sp_adddistributiondb @database = '$DistributionDb', @security_mode = 1;
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii


Write-Host "Opening generated file '$filePath' in Notepad" -ForegroundColor Yellow
notepad $filePath
