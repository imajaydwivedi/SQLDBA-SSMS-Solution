USE DBA
GO
IF OBJECT_ID('dbo.fn_IsJobRunning') IS NULL
	EXEC ('CREATE FUNCTION dbo.fn_IsJobRunning() RETURNS BIT BEGIN RETURN 1 END');
GO
ALTER FUNCTION dbo.fn_IsJobRunning(@p_JobName VARCHAR(2000)) 
	RETURNS BIT
AS
BEGIN
	/*
		Created By:		Ajay Dwivedi
		Created Date:	Apr 07, 2019
		Version:			0.0
	*/
	DECLARE @returnValue BIT
	SET @returnValue = 0;

	IF EXISTS(	SELECT	1
				FROM msdb.dbo.sysjobactivity ja 
				LEFT JOIN msdb.dbo.sysjobhistory jh 
					ON ja.job_history_id = jh.instance_id
				JOIN msdb.dbo.sysjobs j 
				ON ja.job_id = j.job_id
				JOIN msdb.dbo.sysjobsteps js
					ON ja.job_id = js.job_id
					AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
				WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
				AND ja.start_execution_date is not null
				AND ja.stop_execution_date is null
				AND LTRIM(RTRIM(j.name)) = @p_JobName
	)
	BEGIN
		SET @returnValue = 1;
	END

	RETURN @returnValue
END
GO

--SELECT dbo.fn_IsJobRunning('(dba) Run-WaitStats')