# Remove local shell variables, modules and clear error pipleline
Remove-Variable * -ErrorAction SilentlyContinue; $Error.Clear()
#Remove-Module *;
#$dbatools_latestversion = ((Get-Module dbatools -ListAvailable | Sort-Object Version -Descending | select -First 1).Version);
#Import-Module dbatools -RequiredVersion $dbatools_latestversion;

#Parameters
[string]$Path = 'C:\Users\Public\Documents\Logs\SqlUpgrade\'
[string]$Distributor = 'distagl'
[string]$Publisher = 'pub1agl'
[string]$Subscriber = 'sub1agl'
[string]$DistributionDb = 'distribution'
[string]$PublisherDb = 'DbaReplPub01'
[string]$SubscriberDb = 'DbaReplSub01'
[string]$ReplWorkingDirectory = '\\distagl\share\'
#[ValidateSet('Snapshot','BackupRestore','SupportOnly')]
[string]$SyncType = 'SupportOnly'
[string]$MostRecentRestoredBackupFile = $null
[bool]$CreatePubDb = $false
[bool]$CreateSubDb = $false

# Primary validations
if($SyncType -eq 'BackupRestore' -and $CreateSubDb -eq $false -and [String]::IsNullOrEmpty($MostRecentRestoredBackupFile)) {
    "Kindly specify `$MostRecentRestoredBackupFile for 'BackupRestore' `$SyncType." | Write-Error -ErrorAction Stop
}
if($CreateSubDb -and $SyncType -eq 'BackupRestore' -and $CreatePubDb) {
    "Kindly set `$CreatePubDb to false when 'BackupRestore' `$SyncType is specified with `$CreateSubDb set to true." | Write-Error -ErrorAction Stop
}
if($CreatePubDb -eq $false) {
    $resultPubDbExist = Invoke-Sqlcmd -ServerInstance $Publisher -Query "select name from sys.databases where name = '$PublisherDb'"
    if([String]::IsNullOrEmpty($resultPubDbExist))
    {
        Write-Host "[$PublisherDb] does not exist on [$Publisher].`nKindly use below tsql to create sample Publisher database-`n`n" -ForegroundColor Yellow
        @"
use master
go
CREATE DATABASE [$PublisherDb]
GO

-- Create test table, and populate
use [$PublisherDb]
go

create table dbo.repl_table_01
(	id bigint identity(1,1) not null,
	remarks char(200) null,
	created_date_publisher datetime2 default sysdatetime()
)
go

alter table [dbo].[repl_table_01] add constraint PK_repl_table_01 primary key nonclustered ([id]);
go

insert dbo.repl_table_01 (remarks)
select 'Before any replication';
go

select @@servername, * from dbo.repl_table_01 order by id asc
go

"@ | Write-Host -ForegroundColor Magenta

        "***************** Please create publisher database first ************" | Write-Error -ErrorAction Stop;
    }
}
if($true)
{
    $resultSubDbExist = Invoke-Sqlcmd -ServerInstance $Subscriber -Query "select name from sys.databases where name = '$SubscriberDb'"
    $isSubDbExisting = $true
    if([String]::IsNullOrEmpty($resultSubDbExist)) {
        $isSubDbExisting = $false
    }
    if($isSubDbExisting -eq $false -and $CreateSubDb -eq $false)
    {
        Write-Host "[$SubscriberDb] does not exist on [$Subscriber].`nKindly use below tsql to create sample subscriber database (or restore it from previous backup copy):-`n`n" -ForegroundColor Yellow
        @"
use master
go
CREATE DATABASE [$SubscriberDb]
GO

-- Create test table, and populate
use [$SubscriberDb]
go

create table dbo.repl_table_01
(	id bigint not null,
	remarks char(200) null,
	created_date_publisher datetime2 default sysdatetime(),
    created_date_subscriber datetime2 default sysdatetime()
)
go

alter table [dbo].[repl_table_01] add constraint PK_repl_table_01 primary key nonclustered ([id]);
go

select @@servername, * from dbo.repl_table_01 order by id asc
go

"@ | Write-Host -ForegroundColor Magenta

        "***************** Please create publisher database first ************" | Write-Error -ErrorAction Stop;
    }
}

# Derived variables
$dtmm = get-date -f 'yyyyMMdd-HHmmsss'
$filePath = Join-Path $Path "Repl-$SyncType`__$($Publisher.Replace('\','_'))__$($PublisherDb)__$($Subscriber.Replace('\','_'))__$($SubscriberDb)__$dtmm.sql"

@"
/* ****** PARAMETERS *****************
`$Path = '$Path'
`$Distributor = '$Distributor'
`$Publisher = '$Publisher'
`$Subscriber = '$Subscriber'
`$DistributionDb = '$DistributionDb'
`$PublisherDb = '$PublisherDb'
`$SubscriberDb = '$SubscriberDb'
`$ReplWorkingDirectory = '$ReplWorkingDirectory'
`$SyncType = '$SyncType'
`$MostRecentRestoredBackupFile = $MostRecentRestoredBackupFile
`$CreatePubDb = $CreatePubDb
`$CreateSubDb = $CreateSubDb
*/

"@ | Out-File -FilePath $filePath -Append -Encoding ascii

# Declare local variables
[String]$distributorSqlInstance = $null
[String]$publisherSqlInstance = $null
[String]$subscriberSqlInstance = $null

# When database is part of AG
$tsqlGetAgReplicas = @"
set nocount on;

declare @db_name sysname;
declare @listener nvarchar(126);

set @db_name = @Database

if OBJECT_ID('tempdb..#availability_database_config') is not null
	drop table #availability_database_config;
-- Availability Database Configurations
SELECT agl.dns_name as ag_listener
	,ag.name AS 'AG Name'
	,ar.replica_server_name AS 'Replica Instance'
	,d.name AS 'Database Name'
	,Location = CASE
		WHEN ar_state.is_local = 1
			THEN N'LOCAL'
		ELSE 'REMOTE'
		END
	,ROLE = CASE
		WHEN ar_state.role_desc IS NULL
			THEN N'DISCONNECTED'
		ELSE ar_state.role_desc
		END
	,ar_state.connected_state_desc AS 'Connection State'
	,ar.availability_mode_desc AS 'Mode'
	,dr_state.synchronization_state_desc AS 'State'
INTO #availability_database_config
FROM (
	(
		sys.availability_groups AS ag JOIN sys.availability_replicas AS ar ON ag.group_id = ar.group_id
		) JOIN sys.dm_hadr_availability_replica_states AS ar_state ON ar.replica_id = ar_state.replica_id
	)
JOIN sys.dm_hadr_database_replica_states dr_state ON ag.group_id = dr_state.group_id
	AND dr_state.replica_id = ar_state.replica_id
JOIN sys.databases d ON d.database_id = dr_state.database_id
JOIN sys.availability_group_listeners agl on agl.group_id = ag.group_id
WHERE d.name = @db_name;

if not exists (select 1 from #availability_database_config)
	print 'Standalone database'

select co.[AG Name] as ag_name, co.ag_listener as [listener], co.[Replica Instance] as primary_replica, ci.[Replica Instance] as secondary_replica
from #availability_database_config co
outer apply (
	select top 1 * from #availability_database_config ci where ci.[Database Name] = co.[Database Name] and ci.ROLE <> 'PRIMARY'
) ci
where co.ROLE = 'PRIMARY';

"@
$resultGetDistributorAgReplicas = Invoke-DbaQuery -SqlInstance $Distributor -Query $tsqlGetAgReplicas -SqlParameters @{ Database = $DistributionDb } -EnableException -ErrorAction Stop

$isDistributorAg = $true
$distributorSqlInstance = Invoke-Sqlcmd -ServerInstance $Distributor -Query 'select @@servername as srv_name' | Select-Object -ExpandProperty srv_name;
if([String]::IsNullOrEmpty($resultGetDistributorAgReplicas)) {
    $isDistributorAg = $false
}

$distributorListener = $resultGetDistributorAgReplicas.listener
$distributorAgName = $resultGetDistributorAgReplicas.ag_name
$distributorPrimary = $resultGetDistributorAgReplicas.primary_replica
$distributorSecondary = $resultGetDistributorAgReplicas.secondary_replica

# When database is to be joined to AG
$tsqlGetAgReplicas2 = @"
set nocount on;

declare @agl sysname;
set @agl = @Listener;

if OBJECT_ID('tempdb..#availability_database_config') is not null
	drop table #availability_database_config;
-- Availability Database Configurations
SELECT agl.dns_name as ag_listener
	,ag.name AS 'AG Name'
	,ar.replica_server_name AS 'Replica Instance'
	,Location = CASE
		WHEN ar_state.is_local = 1
			THEN N'LOCAL'
		ELSE 'REMOTE'
		END
	,ROLE = CASE
		WHEN ar_state.role_desc IS NULL
			THEN N'DISCONNECTED'
		ELSE ar_state.role_desc
		END
	,ar_state.connected_state_desc AS 'Connection State'
	,ar.availability_mode_desc AS 'Mode'
INTO #availability_database_config
FROM (
	(
		sys.availability_groups AS ag JOIN sys.availability_replicas AS ar ON ag.group_id = ar.group_id
		) JOIN sys.dm_hadr_availability_replica_states AS ar_state ON ar.replica_id = ar_state.replica_id
	)
JOIN sys.availability_group_listeners agl on agl.group_id = ag.group_id
WHERE agl.dns_name = @agl;

if not exists (select 1 from #availability_database_config)
	print 'Standalone database'
else
with t_local_primary as (
	select top 1 * from #availability_database_config lp where lp.Location = 'LOCAL' and ROLE = 'PRIMARY' order by ag_listener asc
)
select p.[AG Name] as ag_name, p.ag_listener as [listener], p.[Replica Instance] as primary_replica, s.[Replica Instance] as secondary_replica
from t_local_primary as p
outer apply (
	select top 1 * from #availability_database_config s where s.ag_listener = p.ag_listener and s.[AG Name] = p.[AG Name] and s.ROLE = 'SECONDARY'
) s;


"@

$resultGetPublisherAgReplicas = Invoke-DbaQuery -SqlInstance $Publisher -Query $tsqlGetAgReplicas -SqlParameters @{ Database = $PublisherDb } -ErrorAction Stop -EnableException
$isPublisherAg = $true
$publisherSqlInstance = Invoke-Sqlcmd -ServerInstance $Publisher -Query 'select @@servername as srv_name' | Select-Object -ExpandProperty srv_name;
if([String]::IsNullOrEmpty($resultGetPublisherAgReplicas))
{
    # If Listener is provided in Publisher name, then assume Publisher will be added to AG of that listener
    if($Publisher -ne $publisherSqlInstance)
    {
        $resultGetPublisherAgReplicas = Invoke-DbaQuery -SqlInstance $Publisher -Query $tsqlGetAgReplicas2 `
                                            -SqlParameters @{ Listener = $Publisher } -ErrorAction Stop -EnableException
    }

    if([String]::IsNullOrEmpty($resultGetPublisherAgReplicas)) {
        $isPublisherAg = $false
    }
}

$publisherListener = $resultGetPublisherAgReplicas.listener
$publisherAgName = $resultGetPublisherAgReplicas.ag_name
$publisherPrimary = $resultGetPublisherAgReplicas.primary_replica
$publisherSecondary = $resultGetPublisherAgReplicas.secondary_replica


$resultGetSubscriberAgReplicas = Invoke-DbaQuery -SqlInstance $Subscriber -Query $tsqlGetAgReplicas -SqlParameters @{ Database = $SubscriberDb } -ErrorAction Stop -EnableException
$isSubscriberAg = $true
$subscriberSqlInstance = Invoke-Sqlcmd -ServerInstance $Subscriber -Query 'select @@servername as srv_name' | Select-Object -ExpandProperty srv_name;
if([String]::IsNullOrEmpty($resultGetSubscriberAgReplicas))
{
    # If Listener is provided in Publisher name, then assume Publisher will be added to AG of that listener
    if($Subscriber -ne $subscriberSqlInstance)
    {
        $resultGetSubscriberAgReplicas = Invoke-DbaQuery -SqlInstance $Subscriber -Query $tsqlGetAgReplicas2 `
                                            -SqlParameters @{ Listener = $Subscriber } -ErrorAction Stop -EnableException
    }

    if([String]::IsNullOrEmpty($resultGetSubscriberAgReplicas)) {
        $isSubscriberAg = $false
    }
}

$subscriberListener = $resultGetSubscriberAgReplicas.listener
$subscriberAgName = $resultGetSubscriberAgReplicas.ag_name
$subscriberPrimary = $resultGetSubscriberAgReplicas.primary_replica
$subscriberSecondary = $resultGetSubscriberAgReplicas.secondary_replica

# Include Listener name in Publication to distinction
$publication = "$( if($isPublisherAg){$publisherListener}else{$publisherSqlInstance.Split('\')[0]} )-2-$( if($isSubscriberAg){$subscriberListener}else{$subscriberSqlInstance.Split('\')[0]} ).$SubscriberDb"

# Step 01: Verify if Distributor is set on Distributor
if($isDistributorAg)
{
    @"
-- Verify if Distributor is configured
	-- On Distributor (primary replica)
:CONNECT $distributorPrimary
SELECT @@SERVERNAME;
GO
EXEC sp_get_distributor;
GO

-- Verify if Distributor is configured
	-- On Distributor (secondary replica)
:CONNECT $distributorSecondary
SELECT @@SERVERNAME;
GO
EXEC sp_get_distributor;
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}
else
{
    @"
-- Verify if Distributor is configured
	-- On Distributor
:CONNECT $distributorSqlInstance
SELECT @@SERVERNAME;
GO
EXEC sp_get_distributor;
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}

# Step 02: Verify if Distributor is set on Publisher
if($isPublisherAg)
{
    @"
-- Verify if Distributor is configured
	-- On Publisher (primary replica)
:CONNECT $publisherPrimary
SELECT @@SERVERNAME;
GO
EXEC sp_get_distributor;
GO

-- Verify if Distributor is configured
	-- On Publisher (secondary replica)
:CONNECT $publisherSecondary
SELECT @@SERVERNAME;
GO
EXEC sp_get_distributor;
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}
else
{
    @"
-- Verify if Distributor is configured for Publisher
	-- On Publisher
:CONNECT $publisherSqlInstance
SELECT @@SERVERNAME;
GO
EXEC sp_get_distributor;
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}


# Step 03: Create publisher database
if($CreatePubDb)
{
    @"
-- On Publisher. Create publisher database
:CONNECT $( if($isPublisherAg){$publisherPrimary}else{$publisherSqlInstance} )
CREATE DATABASE [$PublisherDb]
GO

-- Create test table, and populate
use [$PublisherDb]
go

create table dbo.repl_table_01
(	id bigint identity(1,1) not null,
	remarks char(200) null,
	created_date_publisher datetime2 default sysdatetime()
)
go

alter table [dbo].[repl_table_01] add constraint PK_repl_table_01 primary key nonclustered ([id]);
go

insert dbo.repl_table_01 (remarks)
select 'Before any replication';
go

select @@servername, * from dbo.repl_table_01 order by id asc
go

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}


# Step 04: Create subscriber database for SupportOnly method
if($isSubDbExisting -eq $false -and $CreateSubDb -and $SyncType -eq 'SupportOnly')
{
    @"
-- On Subscriber. Create subscriber database
:CONNECT $( if($isSubscriberAg){$subscriberPrimary}else{$subscriberSqlInstance} )
use master
go
CREATE DATABASE [$SubscriberDb]
GO

-- Create test table, and populate
use [$SubscriberDb]
go

create table dbo.repl_table_01
(	id bigint not null,
	remarks char(200) null,
	created_date_publisher datetime2 default sysdatetime()
)
go

alter table [dbo].[repl_table_01] add constraint PK_repl_table_01 primary key nonclustered ([id]);
go

select @@servername, * from dbo.repl_table_01 order by id asc
go

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}


# Step 04: Create subscriber database for Snapshot Sync Method
if($CreateSubDb -and $SyncType -eq 'Snapshot')
{
    @"
-- On Subscriber. Create subscriber database
:CONNECT $( if($isSubscriberAg){$subscriberPrimary}else{$subscriberSqlInstance} )
CREATE DATABASE [$SubscriberDb]
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}


# Step 05: On Distributor primary replica, set Publisher entry (point to Pub Primary replica)
@"
-- On Distributor primary replica, set Publisher entry (point to Primary replica)
:CONNECT $( if($isDistributorAg){$DistributorPrimary}else{$distributorSqlInstance} )
USE master;
EXEC sp_adddistpublisher @publisher = N'$( if($isPublisherAg){$publisherPrimary}else{$publisherSqlInstance} )',
    @distribution_db = N'$DistributionDb', @security_mode = 1,
    @working_directory = N'$ReplWorkingDirectory', @thirdparty_flag = 0, -- if SQL and not another product
    @publisher_type = N'MSSQLSERVER';
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
if($isPublisherAg)
{
    @"
-- On Distributor primary replica, set Publisher entry (point to Secondary replica)
:CONNECT $( if($isDistributorAg){$DistributorPrimary}else{$distributorSqlInstance} )
USE master;
EXEC sp_adddistpublisher @publisher = N'$publisherSecondary',
    @distribution_db = N'$DistributionDb', @security_mode = 1,
    @working_directory = N'$ReplWorkingDirectory', @thirdparty_flag = 0, -- if SQL and not another product
    @publisher_type = N'MSSQLSERVER';
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}


# Step 06: On Distributor secondary replica, set Publisher entry (point to Pub Primary replica)
if($isDistributorAg)
{
    @"
-- On Distributor secondary replica, set Publisher entry (point to Primary replica)
:CONNECT $distributorSecondary
USE master;
EXEC sp_adddistpublisher @publisher = N'$( if($isPublisherAg){$publisherPrimary}else{$publisherSqlInstance} )',
    @distribution_db = N'$DistributionDb', @security_mode = 1,
    @working_directory = N'$ReplWorkingDirectory', @thirdparty_flag = 0, -- if SQL and not another product
    @publisher_type = N'MSSQLSERVER';
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}
if($isPublisherAg)
{
    @"
-- On Distributor Secondary replica, set Publisher entry (point to Secondary replica)
:CONNECT $distributorSecondary
USE master;
EXEC sp_adddistpublisher @publisher = N'$publisherSecondary',
    @distribution_db = N'$DistributionDb', @security_mode = 1,
    @working_directory = N'$ReplWorkingDirectory', @thirdparty_flag = 0, -- if SQL and not another product
    @publisher_type = N'MSSQLSERVER';
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}


# Step 07: On Publisher, Set Distributor Server
@"
-- On Publisher (primary replica), Set Distributor Server
:CONNECT $( if($isPublisherAg){$publisherPrimary}else{$publisherSqlInstance} )
USE master;
EXEC sp_adddistributor @distributor = N'$( if($isDistributorAg){$distributorListener}else{$distributorSqlInstance} )',
                       @password = N'Pass@word1'; /* distributor_admin password used in distributor linked server RPC connection */
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii

if($isPublisherAg)
{
@"
-- On Publisher (secondary replica), Set Distributor Server
:CONNECT $publisherSecondary
USE master;
EXEC sp_adddistributor @distributor = N'$( if($isDistributorAg){$distributorListener}else{$distributorSqlInstance} )',
                       @password = N'Pass@word1'; /* distributor_admin password used in distributor linked server RPC connection */
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}


# Step 08: On Publisher, mark publisher db for replication
@"
-- On Publisher, mark publisher db for replication
:CONNECT $( if($isPublisherAg){$publisherPrimary}else{$publisherSqlInstance} )
USE [master];
EXEC sp_replicationdboption @dbname = N'$PublisherDb',
    -- Can be "subscribe", "publish", "merge publish"
    -- and "sync with backup"
    @optname = N'publish', -- any type of publication
    @value = N'true';
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii


# Step 09: On Publisher, create publication
if($SyncType -in ('Snapshot','SupportOnly'))
{
    @"
-- On Publisher.PublisherDb, create publication
	-- This will create Log Reader Agent job
:CONNECT $( if($isPublisherAg){$publisherPrimary}else{$publisherSqlInstance} )
USE [$PublisherDb];
EXEC sp_addpublication @publication = N'$publication',
    @sync_method = N'concurrent', @allow_push = N'true', @allow_pull = N'true',
    @snapshot_in_defaultfolder = N'true', @compress_snapshot = N'false',
    @repl_freq = N'continuous', @status = N'active',
    @independent_agent = N'true',
    -- We'll talk more about immediate sync
    -- Big overhead considerations!
    @immediate_sync = N'false', @replicate_ddl = 1,
    @allow_initialize_from_backup = N'false', @enabled_for_p2p = N'false',
    @enabled_for_het_sub = N'false';
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}
elseif($SyncType -eq 'BackupRestore')
{
    @"
-- On Publisher.PublisherDb, create publication
:CONNECT $( if($isPublisherAg){$publisherPrimary}else{$publisherSqlInstance} )
USE [$PublisherDb];
EXEC sp_addpublication @publication = N'$publication',
    @sync_method = N'concurrent', @allow_push = N'true', @allow_pull = N'true',
    @snapshot_in_defaultfolder = N'true', @compress_snapshot = N'false',
    @repl_freq = N'continuous', @status = N'active',
    @independent_agent = N'true',
    -- We'll talk more about immediate sync
    -- Big overhead considerations!
    @immediate_sync = N'false', @replicate_ddl = 1,
    @allow_initialize_from_backup = N'true', @enabled_for_p2p = N'false',
    @enabled_for_het_sub = N'false';
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}

# Step 10: On Publisher, Add the publication articles
if($CreatePubDb -eq $false)
{
    $tsqlGenerateAddArticle = @"
select [tsql] = 'EXEC sp_addarticle @publication = '''+@Publication+''', @article = '''+t.name+''', @source_object = '''+t.name+''', @source_owner = '''+SCHEMA_NAME(t.schema_id)+''';'
from sys.tables t
where t.is_ms_shipped = 0
	and exists(select 1 from sys.indexes i
				where i.object_id = t.object_id
					and i.is_primary_key = 1
			);
"@

$resultGenerateAddArticle = Invoke-DbaQuery -SqlInstance $(if($isPublisherAg){$publisherPrimary}else{$publisherSqlInstance}) `
                            -Database $PublisherDb `
                            -Query $tsqlGenerateAddArticle `
                            -SqlParameters @{ Publication = $publication } `
                            -ErrorAction Stop -EnableException

$strAddPublicationArticle = (($resultGenerateAddArticle.tsql) -join "`nGO`n") + "`nGO`n"
@"
-- On Publisher.PublisherDb, Add articles for publication
:CONNECT $( if($isPublisherAg){$publisherPrimary}else{$publisherSqlInstance} )
USE [$PublisherDb];
$strAddPublicationArticle

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}
else
{
    @"
-- On Publisher.PublisherDb, Add articles for publication
:CONNECT $( if($isPublisherAg){$publisherPrimary}else{$publisherSqlInstance} )
USE [$PublisherDb];
EXEC sp_addarticle @publication = '$publication', @article = 'repl_table_01', @source_object = 'repl_table_01', @source_owner = 'dbo';
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}

# Step 11: On Publisher, Create the snapshot agent without schedule
if($SyncType -eq 'Snapshot') # Skipping this Snapshot Agent creation code
{
    @"
-- On publisher, Create the snapshot agent without schedule
:CONNECT $( if($isPublisherAg){$publisherPrimary}else{$publisherSqlInstance} )
USE [$PublisherDb];
EXEC sp_addpublication_snapshot @publication = N'$publication', @frequency_type = 1
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}


# Step 12: For BackupRestore Sync Method, Restore the Publisher Database on Subscriber
if($CreateSubDb -and $SyncType -eq 'BackupRestore')
{
    $fullBackupPath = Join-Path $ReplWorkingDirectory "$PublisherDb`_FULL_$dtmm.bak"
    $logBackupPath = Join-Path $ReplWorkingDirectory "$PublisherDb`_LOG_$dtmm.trn"

    @"
-- On Publisher, Backup publisher database
:Connect $publisherSqlInstance
USE master
go
Backup Database [$PublisherDb] to Disk = '$fullBackupPath'
Go
Backup LOG [$PublisherDb] to Disk = '$logBackupPath'
Go

"@ | Out-File -FilePath $filePath -Append -Encoding ascii

$resultSourceFilePath = Invoke-Sqlcmd -ServerInstance $publisherSqlInstance -Database $PublisherDb -Query "select @@servername as srv_name, SERVERPROPERTY('InstanceName') as instance_base_name, name as logical_name, type_desc, physical_name from sys.database_files"
$resultDestinationInstanceBaseName = Invoke-Sqlcmd -ServerInstance $subscriberSqlInstance -Query "select SERVERPROPERTY('InstanceName') as instance_base_name"
$dataFilePathSource = $resultSourceFilePath | Where-Object {$_.type_desc -eq 'ROWS'}
$logFilePathSource = $resultSourceFilePath | Where-Object {$_.type_desc -eq 'LOG'}

# If instance on Publisher & Subscriber not not DEFAULT & different Instance Name
    # Replace Publisher instance name with Subscriber instance name in PhysicalName
if($resultSourceFilePath[0].instance_base_name -ne $resultDestinationInstanceBaseName.instance_base_name) {
    $dataFilePathDestination = ($dataFilePathSource.physical_name -replace $resultSourceFilePath[0].instance_base_name,$resultDestinationInstanceBaseName.instance_base_name)
    $logFilePathDestination = ($logFilePathSource.physical_name -replace $resultSourceFilePath[0].instance_base_name,$resultDestinationInstanceBaseName.instance_base_name)
}

$dataFilePathDestination = $dataFilePathSource.physical_name -replace $PublisherDb, $SubscriberDb
$logFilePathDestination = $logFilePathSource.physical_name -replace $PublisherDb, $SubscriberDb


@"
-- On Subscriber, restore database
:CONNECT $subscriberSqlInstance
use master
GO
RESTORE Database [$SubscriberDb] FROM Disk = '$fullBackupPath' WITH NORECOVERY, STATS = 5
		,move '$PublisherDb' to '$dataFilePathDestination'
		,move '$PublisherDb`_log' to '$logFilePathDestination'
Go
RESTORE LOG [$SubscriberDb] FROM Disk = '$logBackupPath' WITH STATS = 5 --,NORECOVERY
Go

"@ | Out-File -FilePath $filePath -Append -Encoding ascii

    $MostRecentRestoredBackupFile = $logBackupPath

}


# Step 13: On Publisher, add subscriber (listener of Subscriber)
@"
-- On Publisher, add subscription (listenter of Subscriber)
	-- This will create Distribution Agent job
:CONNECT $( if($isPublisherAg){$publisherPrimary}else{$publisherSqlInstance} )
USE [$PublisherDb];
go
exec sp_addsubscriber @subscriber = '$Subscriber'
go

"@ | Out-File -FilePath $filePath -Append -Encoding ascii



# Step 13: On Publisher, add subscription (listenter of Subscriber)
if($SyncType -eq 'Snapshot')
{
    @"
-- On Publisher, add subscription (listenter of Subscriber)
	-- This will create Distribution Agent job
:CONNECT $( if($isPublisherAg){$publisherPrimary}else{$publisherSqlInstance} )
USE [$PublisherDb];
EXEC sp_addsubscription
    @publication = N'$publication',
    @subscriber = N'$( if($isSubscriberAg){$subscriberListener}else{$subscriberSqlInstance} )',
    @destination_db = N'$SubscriberDb',
    @subscription_type = N'Push', -- Pull for pull subscription
    @article = N'all',
    @sync_type = N'automatic'
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}
elseif($SyncType -eq 'SupportOnly')
{
    @"
-- On Publisher, add subscription (listenter of Subscriber)
	-- This will create Distribution Agent job
:CONNECT $( if($isPublisherAg){$publisherPrimary}else{$publisherSqlInstance} )
USE [$PublisherDb];
EXEC sp_addsubscription
    @publication = N'$publication',
    @subscriber = N'$( if($isSubscriberAg){$subscriberListener}else{$subscriberSqlInstance} )',
    @destination_db = N'$SubscriberDb',
    @subscription_type = N'Push', -- Pull for pull subscription
    @article = N'all',
    @sync_type = N'replication support only'
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}
elseif($SyncType -eq 'BackupRestore')
{
    @"
-- On Publisher, add subscription (listenter of Subscriber)
	-- This will create Distribution Agent job
:CONNECT $( if($isPublisherAg){$publisherPrimary}else{$publisherSqlInstance} )
USE [$PublisherDb];
EXEC sp_addsubscription
    @publication = N'$publication',
    @subscriber = N'$( if($isSubscriberAg){$subscriberListener}else{$subscriberSqlInstance} )',
    @destination_db = N'$SubscriberDb',
    @subscription_type = N'Push', -- Pull for pull subscription
    @article = N'all',
    @sync_type = N'initialize with backup',
    @backupdevicetype = 'disk',
    @backupdevicename = '$MostRecentRestoredBackupFile'
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}


# Step 13: On Distributor, Redirect Publiser to AG Listener
if($isPublisherAg)
{
    @"
:CONNECT $( if($isDistributorAg){$distributorPrimary}else{$distributorSqlInstance} )
use [$DistributionDb]
go
exec sp_redirect_publisher @original_publisher = '$publisherPrimary',
                           @publisher_db = '$PublisherDb',
                           @redirected_publisher = '$publisherListener'
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii

    <#
    if($isDistributorAg)
    {
        @"
:CONNECT $distributorSecondary
use [$DistributionDb]
go
exec sp_redirect_publisher @original_publisher = '$publisherPrimary',
                           @publisher_db = '$PublisherDb'  ,
                           @redirected_publisher = '$publisherListener'
GO

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
    }
    #>
}


# Step 14: On Distributor, Start/Disable Snapshot Agent Job if SyncType is Snapshot
if($SyncType -eq 'Snapshot')
{
    @"

-- On Distributor, Start/Disable Snapshot Agent Job if SyncType is Snapshot
:CONNECT $(if($isDistributorAg){$distributorPrimary}else{$distributorSqlInstance})
use [$DistributionDb]
go
Declare @snapshot_agent_job_name nvarchar(256);

SELECT @snapshot_agent_job_name = sa.name
FROM MSpublications p
OUTER APPLY (	select distinct s.publication_id, s.subscriber_id, s.subscriber_db, s.subscription_type
				from MSsubscriptions s
				where s.publication_id = p.publication_id
			) AS s
JOIN MSreplservers ss ON s.subscriber_id = ss.srvid
JOIN MSreplservers srv ON srv.srvid = p.publisher_id
JOIN MSdistribution_agents da ON da.publisher_id = p.publisher_id AND da.subscriber_id = s.subscriber_id and da.publication = p.publication and da.subscriber_db = s.subscriber_db
JOIN MSlogreader_agents la ON la.publisher_id = p.publisher_id and la.publisher_db = p.publisher_db --and la.publication = p.publication
LEFT JOIN MSsnapshot_agents sa ON sa.publisher_id = p.publisher_id and sa.publisher_db = p.publisher_db and sa.publication = p.publication
WHERE p.publication = '$publication';

select tsql_disable_job = 'EXEC msdb.dbo.sp_update_job @job_name = N'''+@snapshot_agent_job_name+''', @enabled = 0;'
        ,tsql_start_job = 'EXEC msdb.dbo.sp_start_job @job_name = N'''+@snapshot_agent_job_name+''';'

EXEC msdb.dbo.sp_start_job @job_name = @snapshot_agent_job_name
go

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}


# Step 15: Remove Identity column from SubscriberDb
if($SyncType -eq 'BackupRestore')
{
    @"
-- On Subscriber (primary replica). Remove Identity column
:CONNECT $( if($isSubscriberAg){$subscriberListener}else{$subscriberSqlInstance} )
use [$SubscriberDb]
go
alter table [dbo].[repl_table_01] add id2 bigint;
go
update [dbo].[repl_table_01]  set id2 = id;
alter table [dbo].[repl_table_01] alter column id2 bigint not null;
alter table [dbo].[repl_table_01] drop constraint PK_repl_table_01;
alter table [dbo].[repl_table_01] drop column id;
EXEC sp_RENAME 'repl_table_01.id2' , 'id', 'COLUMN';
go
alter table [dbo].[repl_table_01] add constraint PK_repl_table_01 primary key nonclustered ([id]);
go

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}


# Step 16: Test Replication

@"

-- On Publisher (primary replica). Populate
:CONNECT $( if($isPublisherAg){$publisherListener}else{$publisherSqlInstance} )
use [$PublisherDb]
go

insert dbo.repl_table_01 (remarks)
select 'After fresh replication setup';
go

select @@servername, * from dbo.repl_table_01 order by id asc
go


-- On Subscriber (primary replica). Verify Data records
:CONNECT $( if($isSubscriberAg){$subscriberListener}else{$subscriberSqlInstance} )
use [$SubscriberDb]
go

select @@servername, * from dbo.repl_table_01 order by id asc
go


-- DR Failover Test -> On Distributor DR Instance, Manual Failover Distributor Ag
:CONNECT $distributorSecondary
USE master;
GO
ALTER AVAILABILITY GROUP [$distributorAgName] FAILOVER
GO


-- On Publisher (primary replica). Populate
:CONNECT $( if($isPublisherAg){$publisherListener}else{$publisherSqlInstance} )
use [$PublisherDb]
go

insert dbo.repl_table_01 (remarks)
select 'After Distributor Ag failover to DR node';
go

select @@servername, * from dbo.repl_table_01 order by id asc
go


-- On Subscriber (primary replica). Verify
:CONNECT $( if($isSubscriberAg){$subscriberListener}else{$subscriberSqlInstance} )
use [$SubscriberDb]
go

select @@servername, * from dbo.repl_table_01 order by id asc
go


-- DR Failover Test -> On Distributor Main Instance, Manual Failover Distributor Ag
:CONNECT $distributorPrimary
USE master;
GO
ALTER AVAILABILITY GROUP [$distributorAgName] FAILOVER
GO


-- On Publisher (primary replica). Populate
:CONNECT $( if($isPublisherAg){$publisherListener}else{$publisherSqlInstance} )
use [$PublisherDb]
go

insert dbo.repl_table_01 (remarks)
select 'After Distributor back on Original Ag replica';
go

select @@servername, * from dbo.repl_table_01 order by id asc
go


-- On Subscriber (primary replica). Verify.
:CONNECT $( if($isSubscriberAg){$subscriberListener}else{$subscriberSqlInstance} )
use [$SubscriberDb]
go

select @@servername, * from dbo.repl_table_01 order by id asc
go

"@ | Out-File -FilePath $filePath -Append -Encoding ascii

if($isPublisherAg)
{
    @"
-- Publisher Failover Test -> Failover to Publisher DR instance
:CONNECT $publisherSecondary
USE master;
GO
ALTER AVAILABILITY GROUP [$publisherAgName] FAILOVER
GO


-- On Publisher (primary replica). Populate
:CONNECT $( if($isPublisherAg){$publisherListener}else{$publisherSqlInstance} )
use [$PublisherDb]
go

insert dbo.repl_table_01 (remarks)
select 'After Publisher failed over to DR';
go

select @@servername, * from dbo.repl_table_01 order by id asc
go


-- On Subscriber (primary replica). Verify.
:CONNECT $( if($isSubscriberAg){$subscriberListener}else{$subscriberSqlInstance} )
use [$SubscriberDb]
go

select @@servername, * from dbo.repl_table_01 order by id asc
go

-- Publisher Failover Test -> Fail Back to Publisher Main instance
:CONNECT $publisherPrimary
USE master;
GO
ALTER AVAILABILITY GROUP [$publisherAgName] FAILOVER
GO


-- On Publisher (primary replica). Populate
:CONNECT $( if($isPublisherAg){$publisherListener}else{$publisherSqlInstance} )
use [$PublisherDb]
go

insert dbo.repl_table_01 (remarks)
select 'Publisher Db failed back on Main Instance';
go

select @@servername, * from dbo.repl_table_01 order by id asc
go


-- On Subscriber (primary replica). Verify.
:CONNECT $( if($isSubscriberAg){$subscriberListener}else{$subscriberSqlInstance} )
use [$SubscriberDb]
go

select @@servername, * from dbo.repl_table_01 order by id asc
go

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}


if($isSubscriberAg)
{
    @"
-- Subscriber Failover Test -> Failover to Subscriber DR instance
:CONNECT $subscriberSecondary
USE master;
GO
ALTER AVAILABILITY GROUP [$subscriberAgName] FAILOVER
GO


-- On Publisher (primary replica). Populate
:CONNECT $( if($isPublisherAg){$publisherListener}else{$publisherSqlInstance} )
use [$PublisherDb]
go

insert dbo.repl_table_01 (remarks)
select 'After Subscriber failed over to DR';
go

select @@servername, * from dbo.repl_table_01 order by id asc
go


-- On Subscriber (primary replica). Verify.
:CONNECT $( if($isSubscriberAg){$subscriberListener}else{$subscriberSqlInstance} )
use [$SubscriberDb]
go

select @@servername, * from dbo.repl_table_01 order by id asc
go

-- Subscriber Failover Test -> Fail Back to Subscriber Main instance
:CONNECT $subscriberPrimary
USE master;
GO
ALTER AVAILABILITY GROUP [$subscriberAgName] FAILOVER
GO


-- On Publisher (primary replica). Populate
:CONNECT $( if($isPublisherAg){$publisherListener}else{$publisherSqlInstance} )
use [$PublisherDb]
go

insert dbo.repl_table_01 (remarks)
select 'Subscriber Db failed back on Main Instance';
go

select @@servername, * from dbo.repl_table_01 order by id asc
go


-- On Subscriber (primary replica). Verify.
:CONNECT $( if($isSubscriberAg){$subscriberListener}else{$subscriberSqlInstance} )
use [$SubscriberDb]
go

select @@servername, * from dbo.repl_table_01 order by id asc
go

"@ | Out-File -FilePath $filePath -Append -Encoding ascii
}

Write-Host "Opening generated file '$filePath' in Notepad" -ForegroundColor Yellow
notepad $filePath

<#
$primaryReplica = 'dist_primary'
$drReplica = 'dist_secondary'

Copy-DbaLinkedServer -Source $primaryReplica -Destination $drReplica
Copy-DbaLinkedServer -Source $drReplica -Destination $primaryReplica

#>