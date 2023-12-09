SET NOCOUNT ON;

DECLARE @LogSpaceUsedThreshold_GB DECIMAL(20,2);
SET @LogSpaceUsedThreshold_GB = 50;

IF OBJECT_ID('tempdb..#LogSpaceTable') IS NOT NULL
	TRUNCATE TABLE #LogSpaceTable;
ELSE
BEGIN
	CREATE TABLE #LogSpaceTable
	(	DbName varchar(200),LogSizeMB decimal(20,8), LogSpaceUsedPercent decimal(10,7), Status int
		,LogSizeGB as cast(LogSizeMB / 1024 as decimal(20,2))
		,LogSpaceUsedGB as cast((LogSizeMB * (LogSpaceUsedPercent / 100)) / 1024 as decimal(20,2))
	)
END

-- Get Log Space Usage Metrics
INSERT #LogSpaceTable
EXEC('dbcc sqlperf(logspace)');

-- Stop the IndexOptimize Jobs if @LogSpaceUsedThreshold_GB is crossed
IF EXISTS (SELECT * FROM #LogSpaceTable as s WHERE s.DbName = 'StackOverflow' AND s.LogSpaceUsedGB >= @LogSpaceUsedThreshold_GB) AND DBA.dbo.fn_IsJobRunning('DBA - IndexOptimize_Modified - StackOverflow') = 1
	EXEC msdb..sp_stop_job @job_name = 'DBA - IndexOptimize_Modified - StackOverflow';
-- Stop the IndexOptimize Jobs if @LogSpaceUsedThreshold_GB is crossed
IF EXISTS (SELECT * FROM #LogSpaceTable as s WHERE s.DbName = 'YouTubeFiltered' AND s.LogSpaceUsedGB >= @LogSpaceUsedThreshold_GB) AND DBA.dbo.fn_IsJobRunning('DBA - IndexOptimize_Modified - YouTubeFiltered') = 1
	EXEC msdb..sp_stop_job @job_name = 'DBA - IndexOptimize_Modified - YouTubeFiltered';
-- Stop the IndexOptimize Jobs if @LogSpaceUsedThreshold_GB is crossed
IF EXISTS (SELECT * FROM #LogSpaceTable as s WHERE s.DbName = 'FacebookFiltered' AND s.LogSpaceUsedGB >= @LogSpaceUsedThreshold_GB) AND DBA.dbo.fn_IsJobRunning('DBA - IndexOptimize_Modified - FacebookFiltered') = 1
	EXEC msdb..sp_stop_job @job_name = 'DBA - IndexOptimize_Modified - FacebookFiltered';

/*
DbName			LogSizeMB		LogSpaceUsedPercent	Status	LogSizeGB	LogSpaceUsedGB
YouTubeFiltered	79999.99218750	0.2588184			0		78.12		0.20
FacebookFiltered	41999.99218750	0.2737445			0		41.02		0.11
StackOverflow			65962.42968750	2.1931520			0		64.42		1.41
*/

