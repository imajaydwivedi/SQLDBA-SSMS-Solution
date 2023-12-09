USE DBA
GO
/*
SQL Agent Job => [(dba) Run-PlanCacheAutopilot]
Job Script => SCH-Job-[(dba) Run-PlanCacheAutoPilot].sql

EXEC dbo.usp_PlanCacheAutopilot
	@MinExecutions = 2,
	@MinDurationSeconds = 10,
	@MinCPUSeconds = 10,
	@MinLogicalReads = 100000,
	@MinLogicalWrites = 0,
	@MinSpills = 0,
	@MinGrantMB = 0,
	@OutputDatabaseName = 'DBA',
	@OutputSchemaName = 'dbo',
	@OutputTableName = 'PlanCacheAutopilot',
	@CheckDateOverride = NULL,
	@LogThePlans = 1,
	@ClearThePlans = 0,
	@Debug = 1;
*/
GO

IF OBJECT_ID('dbo.usp_PlanCacheAutopilot') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_PlanCacheAutopilot AS RETURN 0;');
GO

ALTER PROC dbo.usp_PlanCacheAutopilot
	@MinExecutions INT = 2,
	@MinDurationSeconds INT = 60,
	@MinCPUSeconds INT = 60,
	@MinLogicalReads INT = 1000000,
	@MinLogicalWrites INT = 0,
	@MinSpills INT = 0,
	@MinGrantMB INT = 0,
	@OutputDatabaseName NVARCHAR(258) = 'DBA',
	@OutputSchemaName NVARCHAR(258) = 'dbo',
	@OutputTableName NVARCHAR(258) = 'PlanCacheAutopilot',
	@CheckDateOverride DATETIMEOFFSET = NULL,
	@LogThePlans BIT = 0,
	@ClearThePlans BIT = 0,
	@Debug BIT = 0,
	@Version VARCHAR(30) = NULL OUTPUT,
	@VersionDate DATETIME = NULL OUTPUT,
	@VersionCheckMode BIT = 0 AS
BEGIN
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT @Version = '0.01', @VersionDate = '20200604';
DECLARE @StringToExec NVARCHAR(MAX),
	@crlf NVARCHAR(2) = NCHAR(13) + NCHAR(10),
	@CurrentPlanHandle VARBINARY(64);

IF @CheckDateOverride IS NULL
	SET @CheckDateOverride = SYSDATETIMEOFFSET();

/* Using DISTINCT because we may have multiple lines in qs for a single plan,
some of which may have met our thresholds, and some not. I'm only freeing them
if specific lines have been bad enough to meet the threshold - it isn't a 
problem if a big proc has dozens/hundreds of fast lines that add up to meet the
threshold in total. */
RAISERROR('Populating #ProblemPlans.', 0, 1) WITH NOWAIT;

CREATE TABLE #ProblemPlans (PlanHandle VARBINARY(64));
INSERT INTO #ProblemPlans (PlanHandle)
SELECT DISTINCT qs.plan_handle
	FROM sys.dm_exec_query_stats qs
	WHERE qs.execution_count >= @MinExecutions
		AND qs.max_elapsed_time >= (@MinDurationSeconds * 1000)
		AND qs.max_worker_time >= (@MinCPUSeconds * 1000)
		AND qs.max_logical_reads >= @MinLogicalReads
		AND qs.max_logical_writes >= @MinLogicalWrites
		AND qs.max_spills >= @MinSpills
		AND qs.max_grant_kb >= (@MinGrantMB * 1024);

IF NOT EXISTS(SELECT * FROM #ProblemPlans)
	BEGIN
	RAISERROR('No plans found meeting the thresholds, exiting.', 0, 1) WITH NOWAIT;
	RETURN;
	END

IF @Debug = 1
	BEGIN
	DROP TABLE IF EXISTS ##ProblemPlans;
	SELECT *
		INTO ##ProblemPlans
		FROM #ProblemPlans;
	END

IF @LogThePlans = 1 AND EXISTS(SELECT * FROM #ProblemPlans) 
	AND @OutputDatabaseName IS NOT NULL AND @OutputSchemaName IS NOT NULL AND @OutputTableName IS NOT NULL
	BEGIN
	RAISERROR('@LogThePlans = 1, so logging the #ProblemPlans to table.', 0, 1) WITH NOWAIT;
	/* Log the plans */

	SELECT @OutputDatabaseName = QUOTENAME(@OutputDatabaseName),
		@OutputSchemaName   = QUOTENAME(@OutputSchemaName),
		@OutputTableName    = QUOTENAME(@OutputTableName);

	RAISERROR('Creating the table if it does not exist.', 0, 1) WITH NOWAIT;
    SET @StringToExec = 'USE '
        + @OutputDatabaseName
        + '; IF EXISTS(SELECT * FROM '
        + @OutputDatabaseName
        + '.INFORMATION_SCHEMA.SCHEMATA WHERE QUOTENAME(SCHEMA_NAME) = '''
        + @OutputSchemaName
        + ''') AND NOT EXISTS (SELECT * FROM '
        + @OutputDatabaseName
        + '.INFORMATION_SCHEMA.TABLES WHERE QUOTENAME(TABLE_SCHEMA) = '''
        + @OutputSchemaName + ''' AND QUOTENAME(TABLE_NAME) = '''
        + @OutputTableName + ''') CREATE TABLE '
        + @OutputSchemaName + '.'
        + @OutputTableName
        + N'(ID bigint NOT NULL IDENTITY(1,1),
		ServerName NVARCHAR(258),
		CheckDate DATETIMEOFFSET,
		plan_generation_num BIGINT,
		creation_time DATETIME,
		last_execution_time DATETIME,
		execution_count BIGINT,
		query_hash BINARY(8),
		query_plan_hash BINARY(8),
		plan_handle VARBINARY(64), 
		query_plan XML NULL,
		query_plan_last_actual XML NULL,
		total_worker_time BIGINT,
		last_worker_time BIGINT,
		min_worker_time BIGINT,
		max_worker_time BIGINT,
		total_logical_writes BIGINT,
		last_logical_writes BIGINT,
		min_logical_writes BIGINT,
		max_logical_writes BIGINT,
		total_logical_reads BIGINT,
		last_logical_reads BIGINT,
		min_logical_reads BIGINT,
		max_logical_reads BIGINT,
		total_clr_time BIGINT,
		last_clr_time BIGINT,
		min_clr_time BIGINT,
		max_clr_time BIGINT,
		total_elapsed_time BIGINT,
		last_elapsed_time BIGINT,
		min_elapsed_time BIGINT,
		max_elapsed_time BIGINT,
		total_rows BIGINT,
		last_rows BIGINT,
		min_rows BIGINT,
		max_rows BIGINT,
		total_dop BIGINT,
		last_dop BIGINT,
		min_dop BIGINT,
		max_dop BIGINT,
		total_grant_kb BIGINT,
		last_grant_kb BIGINT,
		min_grant_kb BIGINT,
		max_grant_kb BIGINT,
		total_used_grant_kb BIGINT,
		last_used_grant_kb BIGINT,
		min_used_grant_kb BIGINT,
		max_used_grant_kb BIGINT,
		total_ideal_grant_kb BIGINT,
		last_ideal_grant_kb BIGINT,
		min_ideal_grant_kb BIGINT,
		max_ideal_grant_kb BIGINT,
		total_reserved_threads BIGINT,
		last_reserved_threads BIGINT,
		min_reserved_threads BIGINT,
		max_reserved_threads BIGINT,
		total_used_threads BIGINT,
		last_used_threads BIGINT,
		min_used_threads BIGINT,
		max_used_threads BIGINT,
		total_columnstore_segment_reads BIGINT,
		last_columnstore_segment_reads BIGINT,
		min_columnstore_segment_reads BIGINT,
		max_columnstore_segment_reads BIGINT,
		total_columnstore_segment_skips BIGINT,
		last_columnstore_segment_skips BIGINT,
		min_columnstore_segment_skips BIGINT,
		max_columnstore_segment_skips BIGINT,
		total_spills BIGINT,
		last_spills BIGINT,
		min_spills BIGINT,
		max_spills BIGINT
		CONSTRAINT [PK_' +REPLACE(REPLACE(@OutputTableName,'[',''),']','') + '] PRIMARY KEY CLUSTERED(ID ASC));';

	IF @Debug = 1
		BEGIN
		PRINT SUBSTRING(@StringToExec, 0, 4000);
		PRINT SUBSTRING(@StringToExec, 4000, 8000);
		PRINT SUBSTRING(@StringToExec, 8000, 12000);
		PRINT SUBSTRING(@StringToExec, 12000, 16000);
		PRINT SUBSTRING(@StringToExec, 16000, 20000);
		PRINT SUBSTRING(@StringToExec, 20000, 24000);
		PRINT SUBSTRING(@StringToExec, 24000, 28000);
		PRINT SUBSTRING(@StringToExec, 28000, 32000);
		PRINT SUBSTRING(@StringToExec, 32000, 36000);
		PRINT SUBSTRING(@StringToExec, 36000, 40000);
		END;

	/* Creates the table */
	EXEC sp_executesql @StringToExec;

	RAISERROR('Building dynamic SQL to log plan metrics based on this version of SQL.', 0, 1) WITH NOWAIT;
    SET @StringToExec = N'USE '+ @OutputDatabaseName + '; '
		+ N' WITH QueryStats AS (SELECT '
		+ QUOTENAME(CAST(SERVERPROPERTY('ServerName') AS NVARCHAR(128)), N'''') + N' AS ServerName, @CheckDateOverride AS CheckDate, '
		+ N' MAX(qs.plan_generation_num) AS plan_generation_num, MAX(qs.creation_time) AS creation_time, MAX(qs.last_execution_time) AS last_execution_time, MAX(qs.execution_count) AS execution_count, query_hash, query_plan_hash, qs.plan_handle, '
		+ N' SUM(total_worker_time) AS total_worker_time, SUM(last_worker_time) AS last_worker_time, SUM(min_worker_time) AS min_worker_time, SUM(max_worker_time) AS max_worker_time, '
		+ N' SUM(total_logical_writes) AS total_logical_writes, SUM(last_logical_writes) AS last_logical_writes, SUM(min_logical_writes) AS min_logical_writes, SUM(max_logical_writes) AS max_logical_writes, '
		+ N' SUM(total_logical_reads) AS total_logical_reads, SUM(last_logical_reads) AS last_logical_reads, SUM(min_logical_reads) AS min_logical_reads, SUM(max_logical_reads) AS max_logical_reads, '
		+ N' SUM(total_clr_time) AS total_clr_time, SUM(last_clr_time) AS last_clr_time, SUM(min_clr_time) AS min_clr_time, SUM(max_clr_time) AS max_clr_time, '
		+ N' SUM(total_elapsed_time) AS total_elapsed_time, SUM(last_elapsed_time) AS last_elapsed_time, SUM(min_elapsed_time) AS min_elapsed_time, SUM(max_elapsed_time) AS max_elapsed_time, '
		+ N' MAX(total_rows) AS total_rows, MAX(last_rows) AS last_rows, MIN(min_rows) AS min_rows, MAX(max_rows) AS max_rows, '
		+ N' MAX(total_dop) AS total_dop, MAX(last_dop) AS last_dop, MIN(min_dop) AS min_dop, MAX(max_dop) AS max_dop, '
		+ N' SUM(total_grant_kb) AS total_grant_kb, SUM(last_grant_kb) AS last_grant_kb, SUM(min_grant_kb) AS min_grant_kb, SUM(max_grant_kb) AS max_grant_kb, '
		+ N' SUM(total_used_grant_kb) AS total_used_grant_kb, SUM(last_used_grant_kb) AS last_used_grant_kb, SUM(min_used_grant_kb) AS min_used_grant_kb, SUM(max_used_grant_kb) AS max_used_grant_kb, '
		+ N' SUM(total_ideal_grant_kb) AS total_ideal_grant_kb, SUM(last_ideal_grant_kb) AS last_ideal_grant_kb, SUM(min_ideal_grant_kb) AS min_ideal_grant_kb, SUM(max_ideal_grant_kb) AS max_ideal_grant_kb, '
		+ N' SUM(total_reserved_threads) AS total_reserved_threads, SUM(last_reserved_threads) AS last_reserved_threads, MIN(min_reserved_threads) AS min_reserved_threads, MAX(max_reserved_threads) AS max_reserved_threads, '
		+ N' MAX(total_used_threads) AS total_used_threads, MAX(last_used_threads) AS last_used_threads, MIN(min_used_threads) AS min_used_threads, MAX(max_used_threads) AS max_used_threads, '
		+ N' SUM(total_columnstore_segment_reads) AS total_columnstore_segment_reads, SUM(last_columnstore_segment_reads) AS last_columnstore_segment_reads, SUM(min_columnstore_segment_reads) AS min_columnstore_segment_reads, SUM(max_columnstore_segment_reads) AS max_columnstore_segment_reads, '
		+ N' SUM(total_columnstore_segment_skips) AS total_columnstore_segment_skips, SUM(last_columnstore_segment_skips) AS last_columnstore_segment_skips, SUM(min_columnstore_segment_skips) AS min_columnstore_segment_skips, SUM(max_columnstore_segment_skips) AS max_columnstore_segment_skips, '
		+ N' SUM(total_spills) AS total_spills, SUM(last_spills) AS last_spills, SUM(min_spills) AS min_spills, SUM(max_spills) AS max_spills '
		+ N' FROM #ProblemPlans p INNER JOIN sys.dm_exec_query_stats qs ON p.PlanHandle = qs.plan_handle '
		+ N' GROUP BY qs.plan_handle, qs.query_hash, qs.query_plan_hash ) ';

	SET @StringToExec = @StringToExec 
        + N' INSERT INTO ' + @OutputSchemaName + '.' + @OutputTableName
        + N'(ServerName, CheckDate, plan_generation_num, creation_time, last_execution_time, execution_count, query_hash, query_plan_hash, plan_handle, '
		+ N' total_worker_time, last_worker_time, min_worker_time, max_worker_time, total_logical_writes, last_logical_writes, min_logical_writes, max_logical_writes, '
		+ N' total_logical_reads, last_logical_reads, min_logical_reads, max_logical_reads, total_clr_time, last_clr_time, min_clr_time, max_clr_time, '
		+ N' total_elapsed_time, last_elapsed_time, min_elapsed_time, max_elapsed_time, total_rows, last_rows, min_rows, max_rows, '
		+ N' total_dop, last_dop, min_dop, max_dop, total_grant_kb, last_grant_kb, min_grant_kb, max_grant_kb, '
		+ N' total_used_grant_kb, last_used_grant_kb, min_used_grant_kb, max_used_grant_kb, total_ideal_grant_kb, last_ideal_grant_kb, min_ideal_grant_kb, max_ideal_grant_kb, '
		+ N' total_reserved_threads, last_reserved_threads, min_reserved_threads, max_reserved_threads, total_used_threads, last_used_threads, min_used_threads, max_used_threads, '
		+ N' total_columnstore_segment_reads, last_columnstore_segment_reads, min_columnstore_segment_reads, max_columnstore_segment_reads, '
		+ N' total_columnstore_segment_skips, last_columnstore_segment_skips, min_columnstore_segment_skips, max_columnstore_segment_skips, '
		+ N' total_spills, last_spills, min_spills, max_spills, query_plan, query_plan_last_actual) '
		+ N' SELECT qs.*, qp.query_plan,  ';

	IF EXISTS (SELECT * FROM sys.all_objects WHERE name = 'dm_exec_query_plan_stats')
		SET @StringToExec = @StringToExec + N' qps.query_plan AS query_plan_last_actual ';
	ELSE
		SET @StringToExec = @StringToExec + N' NULL AS query_plan_last_actual ';

	SET @StringToExec = @StringToExec 
		+ N' FROM QueryStats qs '
		+ N' OUTER APPLY sys.dm_exec_query_plan(qs.plan_handle) qp ';

	IF EXISTS (SELECT * FROM sys.all_objects WHERE name = 'dm_exec_query_plan_stats')
		SET @StringToExec = @StringToExec + N' OUTER APPLY sys.dm_exec_query_plan_stats(qs.plan_handle) qps; ';

	IF @Debug = 1
		BEGIN
		PRINT SUBSTRING(@StringToExec, 0, 4000);
		PRINT SUBSTRING(@StringToExec, 4000, 8000);
		PRINT SUBSTRING(@StringToExec, 8000, 12000);
		PRINT SUBSTRING(@StringToExec, 12000, 16000);
		PRINT SUBSTRING(@StringToExec, 16000, 20000);
		PRINT SUBSTRING(@StringToExec, 20000, 24000);
		PRINT SUBSTRING(@StringToExec, 24000, 28000);
		PRINT SUBSTRING(@StringToExec, 28000, 32000);
		PRINT SUBSTRING(@StringToExec, 32000, 36000);
		PRINT SUBSTRING(@StringToExec, 36000, 40000);
		END;

	RAISERROR('Running dynamic SQL to log plan metrics based on this version of SQL.', 0, 1) WITH NOWAIT;
	EXEC sp_executesql @StringToExec, N'@CheckDateOverride DATETIMEOFFSET', @CheckDateOverride;
	END

/* AFTER saving the plans' metrics, free them: */
IF @ClearThePlans = 1 AND EXISTS(SELECT * FROM #ProblemPlans)
	BEGIN
	RAISERROR('@ClearThePlans = 1, so clearing the plans from cache.', 0, 1) WITH NOWAIT;

	RAISERROR('Building the dynamic SQL to clear the problem plans.', 0, 1) WITH NOWAIT;
	SET @StringToExec = (SELECT N'DBCC FREEPROCCACHE (' + CONVERT(NVARCHAR(128), qs.PlanHandle, 1) + N');'
		FROM #ProblemPlans qs
		FOR XML PATH (''));

	IF @Debug = 1
		BEGIN
		PRINT SUBSTRING(@StringToExec, 0, 4000);
		PRINT SUBSTRING(@StringToExec, 4000, 8000);
		PRINT SUBSTRING(@StringToExec, 8000, 12000);
		PRINT SUBSTRING(@StringToExec, 12000, 16000);
		PRINT SUBSTRING(@StringToExec, 16000, 20000);
		PRINT SUBSTRING(@StringToExec, 20000, 24000);
		PRINT SUBSTRING(@StringToExec, 24000, 28000);
		PRINT SUBSTRING(@StringToExec, 28000, 32000);
		PRINT SUBSTRING(@StringToExec, 32000, 36000);
		PRINT SUBSTRING(@StringToExec, 36000, 40000);
		END;

	/* Frees the plan cache */
	RAISERROR('Running the dynamic SQL to clear the problem plans.', 0, 1) WITH NOWAIT;
	EXEC sp_executesql @StringToExec;

	
	END
END

GO


/* For debugging:

SELECT * FROM ##ProblemPlans p
INNER JOIN sys.dm_exec_query_stats qs ON p.PlanHandle = qs.plan_handle
WHERE p.PlanHandle = 0x0500040040C37F1A2039DA107502000001000000000000000000000000000000000000000000000000000000
ORDER BY p.PlanHandle;

SELECT COUNT(*) FROM DBA.dbo.PlanCacheAutopilot;
SELECT TOP 100 * FROM DBA.dbo.PlanCacheAutopilot;

DROP TABLE IF EXISTS DBA.dbo.PlanCacheAutopilot;
*/




/*
MIT License

Copyright (c) 2021 Brent Ozar Unlimited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/