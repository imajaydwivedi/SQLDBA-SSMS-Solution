USE [DBA]
GO

IF OBJECT_ID('dbo.usp_GetLogWalkJobHistoryAlert') IS NULL
	EXEC('CREATE PROCEDURE [dbo].[usp_GetLogWalkJobHistoryAlert] AS SELECT 1 AS [Dummy];')
GO

ALTER PROCEDURE [dbo].[usp_GetLogWalkJobHistoryAlert] 
		@p_JobName VARCHAR(125),
		@p_GetSessionRequestDetails BIT = 0,
		@p_Verbose BIT = 0,
		@p_NoOfContinousFailuresThreshold TINYINT = 2,
		@p_SendMail BIT = 0,
		@p_Mail_TO VARCHAR(1000) = NULL,
		@p_Mail_CC VARCHAR(1000) = NULL
AS
BEGIN 
	/*
		Created By:		Ajay Kumar Dwivedi
		Created Date:	17-Mar-2019
		Purpose:		To have custom alerting system for Log Walk jobs
	*/
	SET NOCOUNT ON;

	IF @p_Verbose = 1
		SELECT [@p_JobName] = @p_JobName;

	IF @p_Verbose = 1
		PRINT 'Declaring local variables..';
	-- Declare Local Variables
	DECLARE @_errorMSG VARCHAR(2000);
	DECLARE @NoOfContinousFailures INT;
	DECLARE @JobHistoryRecordCounts INT;
	DECLARE @SQLString NVARCHAR(2000);
	DECLARE @ParmDefinition NVARCHAR(500);
	DECLARE @T_JobHistory TABLE (RID INT, Server varchar(125),JobName varchar(125),Instance_Id bigint, Step_Id int, Step_Name varchar(125), Run_Status int, Run_Status_Desc varchar(20), Enabled bit, Category_Id int, RunDateTime datetime, RunDurationMinutes int);
	DECLARE @_collection_time_start datetime;
	DECLARE @_collection_time_end datetime;
	DECLARE @IsBlockingIssue BIT;
	DECLARE @_mailSubject VARCHAR(255)
			,@_mailBody VARCHAR(4000);


	-- Check @p_JobName
	IF @p_JobName IS NULL
	BEGIN
		SET @_errorMSG = 'Kindly provide value for parameter @p_JobName.';
		IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
			EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
		ELSE
			EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
	END

	-- Make sure either user wants mail or want to debug, or want both
	IF @p_SendMail = 0 AND @p_Verbose = 0 AND @p_GetSessionRequestDetails = 0
	BEGIN
		SET @_errorMSG = 'Kindly use at least one of the following parameters:- @p_SendMail, @p_Verbose, or @p_GetSessionRequestDetails';
		IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
			EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
		ELSE
			EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
	END


	IF @p_Verbose = 1
		PRINT 'Trying to find Job history..';
	SET @ParmDefinition = N'@_JobName VARCHAR(125)'; 
	SET @SQLString = '
		SELECT	TOP 20 
				ROW_NUMBER() OVER(ORDER BY j.name, h.instance_id desc) AS RID,
				h.server,
				[JobName] = j.name,
				h.instance_id,
				h.step_id,
				h.step_name,
				h.run_status,
				[run_status_desc] = (case when h.run_status = 0 then ''Failed'' when h.run_status =  1 then ''Succeeded'' when h.run_status =  2 then ''Retry'' when h.run_status =  3 then ''Canceled'' else ''In Progress'' END),
				j.enabled,
				j.category_id,
				[RunDateTime] = msdb.dbo.agent_datetime(run_date, run_time),
				[RunDurationMinutes] = ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60)
		FROM	msdb.dbo.sysjobs j 
		INNER JOIN msdb.dbo.sysjobhistory h 
			ON	j.job_id = h.job_id 
		WHERE	j.name = @_JobName
			AND step_id = 0
		ORDER BY JobName, instance_id desc
	';
	INSERT @T_JobHistory
	EXECUTE sp_executesql @SQLString, @ParmDefinition,  
						  @_JobName = @p_JobName; 

	SET @JobHistoryRecordCounts = COALESCE((SELECT COUNT(*) FROM @T_JobHistory),0);

	-- Check if no job history found, or Job name is invalid
	IF @JobHistoryRecordCounts = 0
	BEGIN
		IF EXISTS(SELECT * FROM msdb..sysjobs as j WHERE j.name = @p_JobName)
			SET @_errorMSG = 'No job execution history found for @p_JobName = '+QUOTENAME(@p_JobName);
		ELSE
			SET @_errorMSG = 'No job named '+QUOTENAME(@p_JobName)+' is found';

		IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
			EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
		ELSE
			EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
	END
	ELSE
	BEGIN -- block if Job History is found
		IF @p_Verbose = 1
		BEGIN
			PRINT 'SELECT * FROM @T_JobHistory;';
			SELECT	Q.*, J.*
			FROM	(	SELECT	'SELECT * FROM @T_JobHistory;' AS RunningQuery	) AS Q
			CROSS JOIN
					@T_JobHistory AS J;

		END

		-- If Job has been failing for more than @p_NoOfContinousFailuresThreshold
		IF ((SELECT COUNT(*) FROM @T_JobHistory WHERE Run_Status = 0 AND RID <= @p_NoOfContinousFailuresThreshold) = @p_NoOfContinousFailuresThreshold)
		BEGIN -- block if failure issue is found
			SELECT @NoOfContinousFailures = COALESCE(MIN(RID)-1,0) FROM @T_JobHistory h WHERE h.Run_Status_Desc = 'Succeeded';
	
			IF @p_Verbose = 1
			BEGIN
				PRINT '@NoOfContinousFailures = '+CAST(@NoOfContinousFailures AS VARCHAR(5));
				PRINT 'Job ['+@p_JobName+'] has been failing continously for last '+cast(@NoOfContinousFailures as varchar(2))+ ' times.'
			END

			SELECT	@_collection_time_start = MIN(h.RunDateTime), @_collection_time_end = GETDATE() --MAX(h.RunDateTime)
			FROM	@T_JobHistory AS h
			WHERE	h.RID <= @NoOfContinousFailures;

			IF @p_Verbose = 1
				SELECT [@_collection_time_start] = @_collection_time_start, [@_collection_time_end] = @_collection_time_end;

			IF @p_Verbose = 1 OR @p_GetSessionRequestDetails = 1 OR @p_SendMail = 1
			BEGIN -- block to show session/request details

				-- Find Job Session along with its Blockers
				IF OBJECT_ID('tempdb..#JobSessionBlockers') IS NOT NULL
					DROP TABLE #JobSessionBlockers;
				;WITH T_JobCaptures AS
				(
					SELECT [dd hh:mm:ss.mss], [dd hh:mm:ss.mss (avg)], [session_id], [sql_text], [sql_command], [login_name], [wait_info], [tasks], [tran_log_writes], [CPU], [tempdb_allocations], [tempdb_current], [blocking_session_id], [blocked_session_count], [reads], [writes], [context_switches], [physical_io], [physical_reads], [locks], [used_memory], [status], [tran_start_time], [open_tran_count], [percent_complete], [host_name], [database_name], [program_name], [additional_info], [start_time], [login_time], [request_id], [collection_time]
					FROM [DBA]..[WhoIsActive_ResultSets] as r
					WHERE r.program_name = ('SQL Job = '+@p_JobName)
						AND r.collection_time >= @_collection_time_start
						AND    r.collection_time <= @_collection_time_end
					--
					UNION ALL
					--
					SELECT r.[dd hh:mm:ss.mss], r.[dd hh:mm:ss.mss (avg)], r.[session_id], r.[sql_text], r.[sql_command], r.[login_name], r.[wait_info], r.[tasks], r.[tran_log_writes], r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[blocking_session_id], r.[blocked_session_count], r.[reads], r.[writes], r.[context_switches], r.[physical_io], r.[physical_reads], r.[locks], r.[used_memory], r.[status], r.[tran_start_time], r.[open_tran_count], r.[percent_complete], r.[host_name], r.[database_name], r.[program_name], r.[additional_info], r.[start_time], r.[login_time], r.[request_id], r.[collection_time]
					FROM T_JobCaptures AS j
					INNER JOIN [DBA]..[WhoIsActive_ResultSets] as r
						ON r.collection_time = j.collection_time
						AND j.blocking_session_id = r.session_id
				)
				SELECT	*
				INTO	#JobSessionBlockers
				FROM	T_JobCaptures;

				-- If Blockers are found
				IF OBJECT_ID('tempdb..#JobSessionBlockers') IS NOT NULL AND EXISTS(SELECT 1 FROM #JobSessionBlockers as jb WHERE jb.program_name = ('SQL Job = '+@p_JobName) AND jb.blocking_session_id IS NOT NULL)
				BEGIN
					SET @IsBlockingIssue = 1;
				END
				ELSE
					SET @IsBlockingIssue = 0;

				IF OBJECT_ID('tempdb..#JobSessionBlockers') IS NOT NULL AND (@p_Verbose = 1 OR @p_GetSessionRequestDetails = 1)
					SELECT	Q.*, DENSE_RANK()OVER(ORDER BY J.collection_time ASC) AS CollectionBatchNO, J.*
					FROM	(	SELECT	'What Was Running' AS RunningQuery	) AS Q
					CROSS JOIN
							#JobSessionBlockers AS J;

			END -- block to show session/request details

			IF @p_SendMail = 1
			BEGIN
				IF @p_Verbose = 1
					PRINT 'Sending mail..';

				SET @_mailSubject = 'SQL Agent Job '+QUOTENAME(@p_JobName)+' Failed for '+cast(@NoOfContinousFailures as varchar(2))+ ' times';
				SELECT @_mailBody = 'Dear '+(CASE WHEN @IsBlockingIssue = 1 THEN 'App-Team' ELSE 'DBA Team' END)+',

SQL Agent Job '+QUOTENAME(@p_JobName)+' has been failing for '+cast(@NoOfContinousFailures as varchar(2))+ ' times continously.

LAST JOB RUN:		'+CAST(jh.RunDateTime AS varchar(50))+'
DURATION:		'+CAST(jh.RunDurationMinutes AS varchar(10))+' Minutes
STATUS: 		Failed
MESSAGES:		'+(CASE WHEN @IsBlockingIssue = 1 THEN 'Job '+QUOTENAME(@p_JobName)+' COULD NOT obtain EXCLUSIVE access of underlying database to start its activity. 
RCA:			Kindly execute below query to find out details of Blockers.

	EXEC DBA..[usp_GetLogWalkJobHistoryAlert] @p_JobName = '''+@p_JobName+''' ,@p_GetSessionRequestDetails = 1;


' ELSE 'Kindly check Job Step Error Message' END)
				FROM	@T_JobHistory as jh
				WHERE	jh.RID = 1;

				SET @_mailBody += '


Thanks & Regards,
SQL Alerts
DBA@contso.com

-- Alert Coming from SQL Agent Job [DBA Log Walk Alerts]
	';
				EXEC msdb..sp_send_dbmail
							@profile_name = @@servername,
							@recipients = @p_Mail_TO,
							@copy_recipients = @p_Mail_CC,
							@subject = @_mailSubject,
							@body = @_mailBody;
			END
		END -- block if failure issue is found
		ELSE
			PRINT 'Job ['+@p_JobName+'] has not crossed threshold of '+cast(@p_NoOfContinousFailuresThreshold as varchar(2))+ ' continous failures. No action required.'
	END -- block if Job History is found
END -- Procedure Body
GO


