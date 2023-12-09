use DBA
go

SET NOCOUNT ON;
SET DEADLOCK_PRIORITY LOW;

DECLARE @_dbNames VARCHAR(MAX);

/* Get Comma Separated List of  Database Names */
select --[database_name] = DB_NAME(mf.database_id), [updateability] = DATABASEPROPERTYEX(DB_NAME(mf.database_id),'Updateability'), [status] = DATABASEPROPERTYEX(DB_NAME(mf.database_id),'Status')
		@_dbNames = COALESCE(@_dbNames+','+DB_NAME(mf.database_id),DB_NAME(mf.database_id))
from sys.master_files as mf
where mf.file_id = 1 and DATABASEPROPERTYEX(DB_NAME(mf.database_id),'Updateability') = 'READ_WRITE' and DATABASEPROPERTYEX(DB_NAME(mf.database_id),'Status') = 'ONLINE'
AND DB_NAME(mf.database_id) NOT IN ('master','tempdb','model','msdb','resourcedb')
--AND mf.database_id not in (select d.database_id from sys.databases as d where d.is_in_standby = 1 or d.source_database_id IS NOT NULL);

--select @_dbNames;

EXECUTE dbo.IndexOptimize_Modified
@Databases = @_dbNames, -- Multiple databases can also be passed here
@TimeLimit = 14400, -- 4 Hours
@FragmentationLow = NULL,
@FragmentationMedium = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
@FragmentationHigh = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
@FragmentationLevel1 = 20,
@FragmentationLevel2 = 30,
@PartitionLevel = 'Y',
@MinNumberOfPages = 1000,
@Resumable = 'Y',
--@SortInTempdb = 'Y',
@MaxDOP = 1, 
--@FillFactor = 70, /* Recommendations says to start with 100, and keep decreasing based on Page Splits/Sec value of server.  */
@LOBCompaction = 'Y', 
@UpdateStatistics = 'ALL',
@OnlyModifiedStatistics = 'Y',
@Indexes = 'ALL_INDEXES', /* Default is not specified. Db1.Schema1.Tbl1.Idx1, Db2.Schema2.Tbl2.Idx2 */
@Delay = 5, /* Introduce 300 seconds of Delay b/w Indexes of Replicated Databases */
@LogToTable = 'Y'
,@Index2FreeSpaceRatio = 2.0
,@Execute = 'Y'
,@ForceReInitiate = 0
,@Verbose = 1

/*
SELECT *
FROM dbo.IndexProcessing_IndexOptimize i
ORDER BY i.Defrag desc, i.IsProcessed desc

*/