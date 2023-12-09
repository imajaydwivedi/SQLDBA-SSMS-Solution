USE DBA
GO

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'IndexOptimize_Modified')
    EXEC ('CREATE PROC dbo.IndexOptimize_Modified AS SELECT ''stub version, to be replaced''')
GO
ALTER PROCEDURE [dbo].[IndexOptimize_Modified]	@Databases nvarchar(max) = NULL,
												@FragmentationLow nvarchar(max) = NULL,
												@FragmentationMedium nvarchar(max) = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
												@FragmentationHigh nvarchar(max) = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE',
												@FragmentationLevel1 int = 50,
												@FragmentationLevel2 int = 80,
												@MinNumberOfPages int = 1000,
												@MaxNumberOfPages int = NULL,
												@SortInTempdb nvarchar(max) = 'N',
												@MaxDOP int = NULL,
												@FillFactor int = NULL,
												@PadIndex nvarchar(max) = NULL,
												@LOBCompaction nvarchar(max) = 'Y',
												@UpdateStatistics nvarchar(max) = NULL,
												@OnlyModifiedStatistics nvarchar(max) = 'N',
												@StatisticsModificationLevel int = NULL,
												@StatisticsSample int = NULL,
												@StatisticsResample nvarchar(max) = 'N',
												@PartitionLevel nvarchar(max) = 'Y',
												@MSShippedObjects nvarchar(max) = 'N',
												@Indexes nvarchar(max) = NULL,
												@TimeLimit int = NULL,
												@Delay int = NULL,
												@WaitAtLowPriorityMaxDuration int = NULL,
												@WaitAtLowPriorityAbortAfterWait nvarchar(max) = NULL,
												@Resumable nvarchar(max) = 'N',
												@AvailabilityGroups nvarchar(max) = NULL,
												@LockTimeout int = NULL,
												@LockMessageSeverity int = 16,
												@DatabaseOrder nvarchar(max) = NULL,
												@DatabasesInParallel nvarchar(max) = 'N',
												@LogToTable nvarchar(max) = 'N',
												@Execute nvarchar(max) = 'Y',
												@Help bit = 0,
												@ForceReInitiate bit = 0,
												@Index2FreeSpaceRatio numeric(20,2) = 2.0
												,@Verbose bit = 0
AS
BEGIN
	SET NOCOUNT ON;

	/*	Created By:			Ajay Dwivedi
		Version:			0.2
		Modifications:		May 18, 2019 - Created for 1st time
							Nov 13, 2021 - https://github.com/imajaydwivedi/SQLDBA-SSMS-Solution/issues/4
	*/
	IF(@Verbose = 1)
		PRINT 'Declaring local variables..';
	DECLARE @_isFreshStart bit = ISNULL(@ForceReInitiate,0);
	DECLARE @c_ID BIGINT;
	DECLARE @c_DbName VARCHAR(125);
	DECLARE @c_ParameterValue VARCHAR(500);
	DECLARE @c_TotalPages BIGINT;
	DECLARE @c_DbName_PreviousIndex VARCHAR(125);
	DECLARE @_DelaySeconds bigint = 0;
	DECLARE @_DelayLength char(8)= '00:00:00'
	DECLARE @c_IndexParameterValue VARCHAR(500);
	DECLARE @_SQLString NVARCHAR(MAX);
	DECLARE @_SQLString_Params NVARCHAR(500);
	DECLARE @tbl_Databases TABLE (ID INT IDENTITY(1,1), DBName VARCHAR(200), HaDrEnabled bit default 0);
	DECLARE @_IndexingStartTime datetime = GETDATE();
	DECLARE @_IndexingEndTime datetime;
	DECLARE @_CountHadrIndexes INT;
	DECLARE @_CountNonHadrIndexes INT;
	DECLARE @_CountMin INT;
	DECLARE @_is_already_printed_frag_query bit = 0;
	DECLARE @_is_already_printed_logspace_check_query bit = 0;
	DECLARE @_log_free_space_mb bigint;

	IF OBJECT_ID('dbo.IndexProcessing_IndexOptimize') IS NULL
	BEGIN
		IF(@Verbose = 1)
			PRINT 'Creating table dbo.IndexProcessing_IndexOptimize';
		--DROP TABLE dbo.IndexProcessing_IndexOptimize
		CREATE TABLE dbo.IndexProcessing_IndexOptimize
			(ID BIGINT IDENTITY(1,1) PRIMARY KEY, DbName varchar(125) NOT NULL, SchemaName varchar(125) NOT NULL, TableName varchar(125) NOT NULL, IndexName varchar(125) NULL, IndexType varchar(50) not null, TotalPages BIGINT NOT NULL, TotalRows BIGINT NOT NULL, AvgFragmentationPcnt numeric(28,2) not null, Defrag bit not null default 1, ParameterValue AS (QUOTENAME(DbName)+'.'+QUOTENAME(SchemaName)+'.'+QUOTENAME(TableName)+'.'+QUOTENAME(IndexName)), EntryTime datetime default getdate(), IsProcessed bit default 0);

		--CREATE NONCLUSTERED INDEX NCI_IsProcessed_DBName ON dbo.IndexProcessing_IndexOptimize(IsProcessed,DbName);
	END
		
	-- Check is specific databases have been mentioned
	IF(@Verbose = 1)
			PRINT 'Populating table @tbl_Databases';
	IF @Databases IS NOT NULL --AND @_isFreshStart = 1
	BEGIN
		WITH t1(DBName,DBs) AS 
		(
			SELECT	CAST(LEFT(@Databases, CHARINDEX(',',@Databases+',')-1) AS VARCHAR(500)) as DBName,
					STUFF(@Databases, 1, CHARINDEX(',',@Databases+','), '') as DBs
			--
			UNION ALL
			--
			SELECT	CAST(LEFT(DBs, CHARINDEX(',',DBs+',')-1) AS VARChAR(500)) AS DBName,
					STUFF(DBs, 1, CHARINDEX(',',DBs+','), '')  as DBs
			FROM t1
			WHERE DBs > ''	
		)
		INSERT @tbl_Databases (DBName, HaDrEnabled)
		SELECT [DBName] = LTRIM(RTRIM(DBName)), 
				HaDrEnabled = (CASE WHEN	d.is_published = 1 OR d.is_subscribed = 1 
											OR d.is_distributor = 1 OR group_database_id is not null
									THEN	1
									ELSE	0
									END)
		FROM t1
		LEFT JOIN sys.databases d ON t1.DBName = d.name
		OPTION (MAXRECURSION 32000);
	END

	IF(@Verbose = 1)
	BEGIN
		PRINT 'SELECT * FROM @tbl_Databases;';
		IF(CAST(SERVERPROPERTY('ProductMajorVersion') AS SMALLINT)> 13)
			SELECT '@tbl_Databases__Hadr__' as RunningQuery, [@_isFreshStart] = @_isFreshStart, STRING_AGG(DBName,', ') AS Dbs FROM @tbl_Databases WHERE HaDrEnabled = 1
			UNION ALL
			SELECT '@tbl_Databases__NonHadr__' as RunningQuery, [@_isFreshStart] = @_isFreshStart, STRING_AGG(DBName,', ') AS Dbs FROM @tbl_Databases WHERE HaDrEnabled = 0;
		ELSE
			SELECT '@tbl_Databases' as RunningQuery, [@_isFreshStart] = @_isFreshStart, * FROM @tbl_Databases;
	END

	-- Check if there is any database for which there is no index to process
	IF(@Verbose = 1 AND @ForceReInitiate = 0)
	begin
		print 'Checking if there is any database for which there is no index to process';
		--select [@_isFreshStart] = @_isFreshStart;
		select 'Previous Index Count for Processing' as RunningQuery, d.DBName, 
				i.[nonqualified-indexes], i.[qualified-indexes], i.processed, i.pending
				,'select * from dbo.IndexProcessing_IndexOptimize' as [for-details]
		from @tbl_Databases as d
		left join (	select DbName, 
							[nonqualified-indexes] = sum(case when ipio.Defrag = 0 then 1 else 0 end),
							[qualified-indexes] = sum(case when ipio.Defrag = 1 then 1 else 0 end),
							processed = sum(case when ipio.Defrag = 1 and ipio.IsProcessed = 1 then 1 else 0 end), 
							pending = sum(case when ipio.Defrag = 1 and ipio.IsProcessed = 0 then 1 else 0 end)
					from dbo.IndexProcessing_IndexOptimize as ipio
					--where ipio.Defrag = 1
					group by DbName
				) i
		on d.DBName = i.DbName
	end

	IF @_isFreshStart = 1 
		OR EXISTS (	select 'Index Count for Processing' as RunningQuery, * 
					from @tbl_Databases as d
					left join (select DbName, processed = sum(case when ipio.IsProcessed = 1 then 1 else 0 end), pending = sum(case when ipio.IsProcessed = 0 then 1 else 0 end)
								from dbo.IndexProcessing_IndexOptimize as ipio
								where ipio.Defrag = 1
								group by DbName
							) i
					on d.DBName = i.DbName
					where i.pending is null or i.pending = 0
				)
	BEGIN
		DECLARE cursor_Databases CURSOR LOCAL FORWARD_ONLY FAST_FORWARD READ_ONLY FOR
							SELECT DBName FROM @tbl_Databases dbs
							WHERE @_isFreshStart = 1
							OR dbs.DBName IN (
								select  d.DBName
								from @tbl_Databases as d
								left join (select DbName, processed = sum(case when ipio.IsProcessed = 1 then 1 else 0 end), pending = sum(case when ipio.IsProcessed = 0 then 1 else 0 end)
											from dbo.IndexProcessing_IndexOptimize as ipio
											where ipio.Defrag = 1
											group by DbName
										) i
								on d.DBName = i.DbName
								where i.pending is null or i.pending = 0
							)
							ORDER BY DBName;

		OPEN cursor_Databases;

		FETCH NEXT FROM cursor_Databases INTO @c_DbName;
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF(@Verbose = 1)
			BEGIN
				PRINT '@c_DbName = '+@c_DbName;
			END

			-- If no remaining index is there to process, repopulate table
			IF ( (NOT EXISTS (SELECT * FROM dbo.IndexProcessing_IndexOptimize WHERE (Defrag = 1 and IsProcessed = 0) and DbName = @c_DbName)) OR (@_isFreshStart = 1) )
			BEGIN
				--SET @_isFreshStart = 1;
				IF(@Verbose = 1)
					PRINT 'Deleting already processed indexes from table dbo.IndexProcessing_IndexOptimize for DbName = '+@c_DbName;
				DELETE FROM dbo.IndexProcessing_IndexOptimize WHERE DbName = @c_DbName;
			END

			SET @_SQLString = '
			USE '+QUOTENAME(@c_DbName)+';

			select	db_name(ips.database_id) as DbName,
					sch.name as SchemaName,
					object_name(ips.object_id) as TableName,
					ind.name as IndexName,
					ips.index_type_desc as IndexType,
					page_count as TotalPages,
					ps.row_count as TotalRows,
					ips.avg_fragmentation_in_percent as [AvgFragmentationPcnt],
					[Defrag] = (CASE WHEN	(case when ips.page_count >= '+CAST(@MinNumberOfPages AS VARCHAR(20))+' then ''Yes'' else ''No'' end) = ''Yes'' 
											and avg_fragmentation_in_percent >= '+CAST(@FragmentationLevel1 AS varchar(20))+' 
											and ind.name is not null
									THEN 1 
									ELSE 0 END)
			from sys.dm_db_index_physical_stats(DB_ID(),NULL,NULL,NULL,''LIMITED'') as ips
			inner join sys.indexes as ind on ips.index_id = ind.index_id and ips.object_id = ind.object_id
			inner join sys.tables as tbl on ips.object_id = tbl.object_id
			inner join sys.schemas as sch on tbl.schema_id = sch.schema_id
			inner join sys.dm_db_partition_stats as ps on ps.object_id = ips.object_id and ps.index_id = ips.index_id
			where ips.alloc_unit_type_desc = ''IN_ROW_DATA''
			ORDER BY  SchemaName, TableName, ips.avg_fragmentation_in_percent DESC
			OPTION (RECOMPILE);
			';

			IF(@Verbose = 1)
			BEGIN
				PRINT 'Repopulating table dbo.IndexProcessing_IndexOptimize with Indexes of DbName = '+@c_DbName;
				IF @_is_already_printed_frag_query = 0
				BEGIN
					PRINT @_SQLString;
					SET @_is_already_printed_frag_query = 1;
				END
			END

			INSERT dbo.IndexProcessing_IndexOptimize
			(DbName, SchemaName, TableName, IndexName, IndexType, TotalPages, TotalRows, AvgFragmentationPcnt, Defrag)
			EXEC(@_SQLString);

			FETCH NEXT FROM cursor_Databases INTO @c_DbName;
		END
	END

	IF(@Verbose = 1)
	BEGIN
		PRINT 'Initializing variable @_CountHadrIndexes, @_CountNonHadrIndexes, @_CountMin ';
	END

	-- Find out Hadr database indexes
	SELECT @_CountHadrIndexes = COUNT(*)
	FROM dbo.IndexProcessing_IndexOptimize as ipio
	WHERE (Defrag = 1 and IsProcessed = 0)
	--AND DbName IN (SELECT d.name FROM sys.databases as d WHERE d.is_published = 1 OR d.is_subscribed = 1 OR d.is_distributor = 1 OR group_database_id is not null)
	AND DbName IN (SELECT d.DBName FROM @tbl_Databases as d WHERE HaDrEnabled = 1);

	-- Find out Non-Hadr database indexes
	SELECT @_CountNonHadrIndexes = COUNT(*)
	FROM dbo.IndexProcessing_IndexOptimize
	WHERE (Defrag = 1 and IsProcessed = 0)
	--AND DbName NOT IN (SELECT d.name FROM sys.databases as d WHERE d.is_published = 1 OR d.is_subscribed = 1 OR d.is_distributor = 1 OR group_database_id is not null) 
	AND DbName IN (SELECT d.DBName FROM @tbl_Databases as d WHERE HaDrEnabled = 0);

	/* Set Bucket Size */
	SELECT @_CountMin =	CASE	WHEN @_CountHadrIndexes = 0 /* When hadr indexes are 0, set bucket count to min(count) of index of non-hadr database */
								THEN (	SELECT TOP 1 COUNT(*) AS index_counts
										FROM dbo.IndexProcessing_IndexOptimize
										WHERE (Defrag = 1 and IsProcessed = 0)
										--AND DbName NOT IN (SELECT d.name FROM sys.databases as d WHERE d.is_published = 1 OR d.is_subscribed = 1 OR d.is_distributor = 1 OR group_database_id is not null)
										AND DbName IN (SELECT d.DBName FROM @tbl_Databases as d WHERE HaDrEnabled = 0)
										GROUP BY DbName ORDER BY COUNT(*) ASC
									)
								WHEN @_CountNonHadrIndexes = 0 /* When non-hadr indexes are 0, set bucket count to min(count) of index of hadr database */
								THEN (	SELECT TOP 1 COUNT(*) AS index_counts
										FROM dbo.IndexProcessing_IndexOptimize
										WHERE (Defrag = 1 and IsProcessed = 0)
										--AND DbName IN (SELECT d.name FROM sys.databases as d WHERE d.is_published = 1 OR d.is_subscribed = 1 OR d.is_distributor = 1 OR group_database_id is not null)
										AND DbName IN (SELECT d.DBName FROM @tbl_Databases as d WHERE HaDrEnabled = 1)
										GROUP BY DbName ORDER BY COUNT(*) ASC
									)
								WHEN @_CountHadrIndexes <= @_CountNonHadrIndexes
								THEN @_CountHadrIndexes
								ELSE @_CountNonHadrIndexes
								END

    IF @_CountMin < 10
        SET @_CountMin = 10;

	IF(@Verbose = 1)
		SELECT 'Bucket Size' AS RunningQuery, [@_CountHadrIndexes] = @_CountHadrIndexes, [@_CountNonHadrIndexes] = @_CountNonHadrIndexes, [@_CountMin] = @_CountMin;

	IF @Verbose = 1
	BEGIN
		SELECT 'Index Counts By Database' as RunningQuery, 'Non-Hadr' as Category, DbName, COUNT(*) AS index_counts
		FROM dbo.IndexProcessing_IndexOptimize
		WHERE (Defrag = 1 and IsProcessed = 0)
		--AND DbName NOT IN (SELECT d.name FROM sys.databases as d WHERE d.is_published = 1 OR d.is_subscribed = 1 OR d.is_distributor = 1 OR group_database_id is not null) 
		AND DbName IN (SELECT d.DBName FROM @tbl_Databases as d WHERE HaDrEnabled = 0)
		GROUP BY DbName
		--
		UNION ALL
		--
		SELECT 'Index Counts By Database' as RunningQuery, 'Hadr' as Category, DbName, COUNT(*) AS index_counts
		FROM dbo.IndexProcessing_IndexOptimize
		WHERE (Defrag = 1 and IsProcessed = 0)
		--AND DbName IN (SELECT d.name FROM sys.databases as d WHERE d.is_published = 1 OR d.is_subscribed = 1 OR d.is_distributor = 1 OR group_database_id is not null) 
		AND DbName IN (SELECT d.DBName FROM @tbl_Databases as d WHERE HaDrEnabled = 1)
		GROUP BY DbName
		ORDER BY COUNT(*) ASC, Category, DbName
	END

	CREATE TABLE #IndexOptimize_Modified_Processing (ID bigint, DbName varchar(125), ParameterValue nvarchar(max), TotalPages bigint, RowRank int, OrderID int );

	IF NOT (@_CountHadrIndexes = 0 OR @_CountNonHadrIndexes = 0)
	BEGIN /* When Hadr + NonHadr indexes */
		INSERT #IndexOptimize_Modified_Processing (ID, DbName, ParameterValue, TotalPages ,RowRank, OrderID)
		SELECT	ID, DbName, ParameterValue, TotalPages ,RowRank = NTILE(@_CountMin)OVER(PARTITION BY IsHadrIndex ORDER BY OrderID), OrderID
		FROM (
			SELECT ID, DbName, ParameterValue, TotalPages, IsHadrIndex = 1, OrderID = ROW_NUMBER()OVER(ORDER BY TotalPages DESC)
			FROM dbo.IndexProcessing_IndexOptimize -- Hadr databases
			WHERE (Defrag = 1 and IsProcessed = 0)
			AND DbName IN (SELECT d.DBName FROM @tbl_Databases as d WHERE HaDrEnabled = 1)
			--
			UNION ALL
			--
			SELECT ID, DbName, ParameterValue, TotalPages, IsHadrIndex = 0, OrderID = ROW_NUMBER()OVER(ORDER BY TotalPages DESC)
			FROM dbo.IndexProcessing_IndexOptimize -- Not Hadr databases
			WHERE (Defrag = 1 and IsProcessed = 0)
			AND DbName IN (SELECT d.DBName FROM @tbl_Databases as d WHERE HaDrEnabled = 0)
		) AS R
		ORDER BY NTILE(@_CountMin)OVER(PARTITION BY IsHadrIndex ORDER BY OrderID), OrderID;
	END
	ELSE
	BEGIN /* When Only either Hadr or NonHadr indexes */
		INSERT #IndexOptimize_Modified_Processing (ID, DbName, ParameterValue, TotalPages ,RowRank, OrderID)
		SELECT	ID, DbName, ParameterValue, TotalPages ,RowRank = NTILE(@_CountMin)OVER(PARTITION BY IsHadrIndex ORDER BY OrderID, DbName), OrderID
		FROM (
			SELECT ID, DbName, ParameterValue, TotalPages, IsHadrIndex = 1, OrderID = ROW_NUMBER()OVER(PARTITION BY DbName ORDER BY TotalPages DESC)
			FROM dbo.IndexProcessing_IndexOptimize -- Hadr databases
			WHERE (Defrag = 1 and IsProcessed = 0)
			AND DbName IN (SELECT d.DBName FROM @tbl_Databases as d WHERE HaDrEnabled = 1)
			--
			UNION ALL
			--
			SELECT ID, DbName, ParameterValue, TotalPages, IsHadrIndex = 0, OrderID = ROW_NUMBER()OVER(PARTITION BY DbName ORDER BY TotalPages DESC)
			FROM dbo.IndexProcessing_IndexOptimize -- Not Hadr databases
			WHERE (Defrag = 1 and IsProcessed = 0)
			AND DbName IN (SELECT d.DBName FROM @tbl_Databases as d WHERE HaDrEnabled = 0)
		) AS R
		ORDER BY NTILE(@_CountMin)OVER(PARTITION BY IsHadrIndex ORDER BY OrderID, DbName), OrderID;
	END

	IF @Verbose = 1
	BEGIN
		PRINT 'SELECT * FROM #IndexOptimize_Modified_Processing;'
		SELECT '#IndexOptimize_Modified_Processing' as RunningQuery, *
		FROM #IndexOptimize_Modified_Processing
		ORDER BY RowRank, OrderID;
	END


	IF(@Verbose = 1)
		PRINT 'Declaring cursor cursor_Indexes for processing of Indexes';
	DECLARE cursor_Indexes CURSOR LOCAL FORWARD_ONLY FAST_FORWARD READ_ONLY FOR
				SELECT ID, DbName, ParameterValue, TotalPages
				FROM #IndexOptimize_Modified_Processing
				ORDER BY RowRank, OrderID;

	OPEN cursor_Indexes;

	FETCH NEXT FROM cursor_Indexes INTO @c_ID, @c_DbName,@c_IndexParameterValue, @c_TotalPages;
	WHILE @@FETCH_STATUS = 0 AND (@TimeLimit IS NULL OR (DATEDIFF(second,@_IndexingStartTime,GETDATE()) < @TimeLimit))
	BEGIN
		IF(@Verbose = 1)
		BEGIN
			PRINT 'Processing Index '+@c_IndexParameterValue;
			IF @Execute = 'Y'
				SELECT [@c_ID] = @c_ID, [@c_DbName] = @c_DbName, [@c_IndexParameterValue] = @c_IndexParameterValue, [@c_TotalPages] = @c_TotalPages;
		END

		-- If Trying to Rebuild/ReOrg continsouly for Hadr involved database, then Delay for 5 Minutes
		IF @c_DbName_PreviousIndex IS NOT NULL AND @c_DbName_PreviousIndex = @c_DbName AND @_CountHadrIndexes > 0 
			AND EXISTS (SELECT 1 FROM @tbl_Databases as d WHERE d.DBName = @c_DbName AND HaDrEnabled = 1)
		BEGIN
			SET @_DelaySeconds = 20 + (@c_TotalPages/10000)*0.56;

			SELECT @_DelayLength =
						(CASE WHEN @_DelaySeconds < 60
							THEN '00:00:'+REPLICATE('0',2-LEN(@_DelaySeconds))+CAST(@_DelaySeconds AS VARCHAR(20))-- Less than a Minute
							WHEN (@_DelaySeconds/60) < 60
							THEN '00:'+REPLICATE('0',2-LEN(@_DelaySeconds/60))+CAST(@_DelaySeconds/60 AS VARCHAR(2))+':'+REPLICATE('0',2-LEN(@_DelaySeconds%60))+CAST(@_DelaySeconds%60 AS VARCHAR(20)) -- Less than an Hour
							ELSE REPLICATE('0',2-LEN(@_DelaySeconds/3600))+CAST(@_DelaySeconds/3600 AS VARCHAR(20))+':'+REPLICATE('0',2-LEN((@_DelaySeconds%3600)/60))+CAST((@_DelaySeconds%3600)/60 AS VARCHAR(20))+':'+REPLICATE('0',2-LEN(@_DelaySeconds%60))+CAST(@_DelaySeconds%60 AS VARCHAR(20))
							END);

			IF @Execute = 'Y'
				WAITFOR DELAY @_DelayLength;
			ELSE
				PRINT CHAR(10)+CHAR(9)+'@_DelayLength = '''+@_DelayLength+''''+CHAR(10);
		END

		-- Check Free Space in Log File
		SET @_SQLString_Params = '@_log_free_space_mb bigint OUTPUT'
		SET @_SQLString = N'

	USE '+QUOTENAME(@c_DbName)+';
	with t_log_free_space as (
	select log_free_space_mb = SUM((size/128 - CAST(FILEPROPERTY(f.name,''SpaceUsed'') AS bigint)/128))
	from sys.database_files f left join sys.filegroups fg on fg.data_space_id = f.data_space_id
	where (not (growth <> 0 and (max_size = -1 or max_size >= size))) and f.type_desc = ''LOG''
	)
	select @_log_free_space_mb = ISNULL(log_free_space_mb,value)
	from t_log_free_space full outer join (select -1 as value) d on 1 = 1

';
		IF(@Verbose = 1)
		BEGIN
			PRINT 'Check for free space on Log file of '''+@c_DbName+'''';
			IF @_is_already_printed_logspace_check_query = 0
			BEGIN
				PRINT @_SQLString;
				SET @_is_already_printed_logspace_check_query = 1;
			END
		END

		IF @Execute = 'Y' OR @Verbose = 1
		BEGIN
			EXECUTE sp_executesql @_SQLString, @_SQLString_Params, @_log_free_space_mb=@_log_free_space_mb OUTPUT;
			IF @Verbose = 1
				PRINT '@_log_free_space_mb = '+cast(@_log_free_space_mb as varchar(20));

			IF @_log_free_space_mb <> -1 AND (((@c_TotalPages/128)*@Index2FreeSpaceRatio) > @_log_free_space_mb)
			BEGIN
				SET @_SQLString = QUOTENAME(@c_DbName)+' => Free Log File Space of '+convert(varchar(20),@_log_free_space_mb)+' MB is not sufficient for index '''+@c_IndexParameterValue+''' of size '+convert(varchar(20), @c_TotalPages/128)+' MB with @Index2FreeSpaceRatio = '+CONVERT(varchar,@Index2FreeSpaceRatio);
				THROW 51000, @_SQLString, 1;
			END
		END

		IF NOT (@Verbose = 1 AND @Execute = 'N')
		BEGIN
			EXECUTE dbo.IndexOptimize
									@Databases = @c_DbName, -- Changed Value
									@FragmentationLow =  @FragmentationLow,
									@FragmentationMedium =  @FragmentationMedium,
									@FragmentationHigh =  @FragmentationHigh,
									@FragmentationLevel1 =  @FragmentationLevel1,
									@FragmentationLevel2 =  @FragmentationLevel2,
									@MinNumberOfPages =  @MinNumberOfPages,
									@MaxNumberOfPages =  @MaxNumberOfPages,
									@SortInTempdb =  @SortInTempdb,
									@MaxDOP =  @MaxDOP,
									@FillFactor =  @FillFactor,
									@PadIndex =  @PadIndex,
									@LOBCompaction =  @LOBCompaction,
									@UpdateStatistics =  @UpdateStatistics,
									@OnlyModifiedStatistics =  @OnlyModifiedStatistics,
									@StatisticsModificationLevel =  @StatisticsModificationLevel,
									@StatisticsSample =  @StatisticsSample,
									@StatisticsResample =  @StatisticsResample,
									@PartitionLevel =  @PartitionLevel,
									@MSShippedObjects =  @MSShippedObjects,
									@Indexes =  @c_IndexParameterValue, -- Changed Value
									@TimeLimit =  @TimeLimit,
									@Delay =  @Delay,
									@WaitAtLowPriorityMaxDuration =  @WaitAtLowPriorityMaxDuration,
									@WaitAtLowPriorityAbortAfterWait =  @WaitAtLowPriorityAbortAfterWait,
									@Resumable =  @Resumable,
									@AvailabilityGroups =  @AvailabilityGroups,
									@LockTimeout =  @LockTimeout,
									@LockMessageSeverity =  @LockMessageSeverity,
									@DatabaseOrder =  @DatabaseOrder,
									@DatabasesInParallel =  @DatabasesInParallel,
									@LogToTable =  @LogToTable,
									@Execute =  @Execute;
		END

		IF @Execute = 'Y'
		BEGIN
			UPDATE dbo.IndexProcessing_IndexOptimize
			SET IsProcessed = 1
			WHERE ID = @c_ID;
		END

		SET @c_DbName_PreviousIndex = @c_DbName;
		FETCH NEXT FROM cursor_Indexes INTO @c_ID, @c_DbName,@c_IndexParameterValue, @c_TotalPages;
	END
END
GO

