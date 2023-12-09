--	https://ola.hallengren.com/sql-server-backup.html


EXECUTE dbo.IndexOptimize /* Update Stats */
			@Databases = 'USER_DATABASES',
			@FragmentationLow = NULL,
			@FragmentationMedium = NULL,
			@FragmentationHigh = NULL,
			@UpdateStatistics = 'ALL',
			@OnlyModifiedStatistics = 'Y',
			@PartitionLevel = 'Y',
			--@Indexes = 'AdventureWorks.Production.Product',
			@MSShippedObjects = 'Y',
			@DatabasesInParallel = 'Y'
go


DECLARE @_dbNames VARCHAR(MAX);

/* Get Comma Separated List of  Database Names which are not on APPSYNC*/
select @_dbNames = COALESCE(@_dbNames+','+DB_NAME(mf.database_id),DB_NAME(mf.database_id))
                 --,mf.physical_name
from sys.master_files as mf
where mf.file_id = 1
         AND mf.database_id <> DB_ID('tempdb')
         AND mf.physical_name not like 'C:\AppSyncMounts\%'
         AND mf.database_id not in (select d.database_id from sys.databases as d where d.is_in_standby = 1 or d.source_database_id IS NOT NULL);

select @_dbNames;


--	Full Backups
EXEC DBA.dbo.[DatabaseBackup]
		@Databases = @_dbNames,
		@Directory = 'E:\Backup', /* Output like 'E:\Backup\backupfile.bak' */ 
		@DirectoryStructure = NULL, /* Do not create directory structure */
		@BackupType = 'FULL', 
		@Compress = 'Y'
		,@CleanupTime = 168 -- 1 week
		,@CleanupMode = 'AFTER_BACKUP';
GO

DECLARE @_dbNames VARCHAR(MAX);

/* Get Comma Separated List of  Database Names which are not on APPSYNC*/
select @_dbNames = COALESCE(@_dbNames+','+DB_NAME(mf.database_id),DB_NAME(mf.database_id))
                 --,mf.physical_name
from sys.master_files as mf
where mf.file_id = 1
         AND DB_NAME(mf.database_id) NOT IN ('master','tempdb','model','msdb','resourcedb')
         AND mf.physical_name not like 'C:\AppSyncMounts\%'
         AND mf.database_id not in (select d.database_id from sys.databases as d where d.is_in_standby = 1 or d.source_database_id IS NOT NULL);

select @_dbNames;

--	Diff Backups
EXEC DBA.dbo.[DatabaseBackup]
		@Databases = @_dbNames,
		@Directory = 'E:\Backup', /* Output like 'E:\Backup\backupfile.bak' */ 
		@DirectoryStructure = NULL, /* Do not create directory structure */
		@BackupType = 'DIFF', 
		@FileExtensionDiff = 'diff',
		@Compress = 'Y'


use DBA
go

/* IndexOptimize [DBA] with @TimeLimit = 3.5 Hour */
EXECUTE dbo.IndexOptimize_Modified
@Databases = 'DBA', -- Multiple databases can also be passed here
@TimeLimit = 5400, -- 3.5 hours
@FragmentationLow = NULL,
@FragmentationMedium = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
@FragmentationHigh = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
@FragmentationLevel1 = 20,
@FragmentationLevel2 = 30,
@MinNumberOfPages = 1000,
@SortInTempdb = 'Y', /* Enable it when [Galaxy] production Server since [tempdb] & [Galaxy] database are on separate disks */
@MaxDOP = 4, /* Default = 3 on Galaxy server */
--@FillFactor = 70, /* Recommendations says to start with 100, and keep decreasing based on Page Splits/Sec value of server. On Galaxy server, Page Splits/sec are very high. Avg 171 page splits/sec for Avg 354 Batch Requests/sec */
@LOBCompaction = 'Y', 
@UpdateStatistics = 'ALL',
@OnlyModifiedStatistics = 'Y',
@Indexes = 'ALL_INDEXES', /* Default is not specified. Db1.Schema1.Tbl1.Idx1, Db2.Schema2.Tbl2.Idx2 */
--@Delay = 120, /* Introduce 300 seconds of Delay b/w Indexes of Replicated Databases */
@LogToTable = 'Y'
,@forceReInitiate = 0
go


EXECUTE DBA.dbo.DatabaseBackup
			@Databases = 'SYSTEM_DATABASES',
			@Directory = 'E:\Backup01',
			@DirectoryStructure = NULL,
			@FileName = '{DatabaseName}.{FileExtension}',
			@BackupType = 'FULL',
			@Verify = 'Y',
			@Compress = 'Y',
			@CheckSum = 'Y',
			@NumberOfFiles = 1,
			@Init = 'Y',
			@Format = 'Y',
			--@DatabasesInParallel = 'Y',
			@LogToTable = 'Y',
			@Execute = 'Y';

EXECUTE DBA.dbo.DatabaseBackup
			@Databases = 'USER_DATABASES,-StackOverflow%',
			@Directory = 'E:\Backup01,E:\Backup02,E:\Backup03,E:\Backup04',
			@DirectoryStructure = NULL,
			@FileName = '{DatabaseName}_{FileNumber}of{NumberOfFiles}.{FileExtension}',
			@BackupType = 'FULL',
			@Verify = 'Y',
			@Compress = 'Y',
			@CheckSum = 'Y',
			@NumberOfFiles = 4,
			@Init = 'Y',
			@Format = 'Y',
			@DatabasesInParallel = 'Y',
			@LogToTable = 'Y',
			@Execute = 'Y'
GO

