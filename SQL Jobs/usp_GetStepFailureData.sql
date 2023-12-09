--	http://www.sqlservercentral.com/articles/SQL+Server+Agent/67726/
USE DBA
GO

IF OBJECT_ID('dbo.usp_GetStepFailureData') IS NULL
	EXEC ('CREATE PROCEDURE dbo.usp_GetStepFailureData AS RETURN 0;');
GO

/*
	EXEC usp_GetStepFailureData 'CW Import AMG Video Data'
*/
ALTER PROCEDURE usp_GetStepFailureData (@JobName VARCHAR(250))
AS
/*
This procedure gets failure log data for the failed step of a SQL Server Agent job
*/
DECLARE @job_id UNIQUEIDENTIFIER

SELECT @job_id = job_id
FROM msdb..sysjobs
WHERE [name] = @JobName

SELECT 'Step ' + CAST(JH.step_id AS VARCHAR(3)) + ' of ' + (
		SELECT CAST(COUNT(*) AS VARCHAR(5))
		FROM msdb..sysjobsteps
		WHERE job_id = @job_id
		) AS StepFailed
	,CAST(RIGHT(JH.run_date, 2) AS CHAR(2)) + '/' + CAST(SUBSTRING(CAST(JH.run_date AS CHAR(8)), 5, 2) AS CHAR(2)) + '/' + CAST(LEFT(JH.run_date, 4) AS CHAR(4)) AS DateRun
	,LEFT(RIGHT('0' + CAST(JH.run_time AS VARCHAR(6)), 6), 2) + ':' + SUBSTRING(RIGHT('0' + CAST(JH.run_time AS VARCHAR(6)), 6), 3, 2) + ':' + LEFT(RIGHT('0' + CAST(JH.run_time AS VARCHAR(6)), 6), 2) AS TimeRun
	,JS.step_name
	,JH.run_duration
	,CASE 
		WHEN JSL.[log] IS NULL
			THEN JH.[Message]
		ELSE JSL.[log]
		END AS LogOutput
FROM msdb..sysjobsteps JS
INNER JOIN msdb..sysjobhistory JH ON JS.job_id = JH.job_id
	AND JS.step_id = JH.step_id
LEFT OUTER JOIN msdb..sysjobstepslogs JSL ON JS.step_uid = JSL.step_uid
WHERE INSTANCE_ID > (
		SELECT MIN(INSTANCE_ID)
		FROM (
			SELECT TOP (2) INSTANCE_ID
				,job_id
			FROM msdb..sysjobhistory
			WHERE job_id = @job_id
				AND STEP_ID = 0
			ORDER BY INSTANCE_ID DESC
			) A
		)
	AND JS.step_id <> 0
	AND JH.job_id = @job_id
	AND JH.run_status = 0
ORDER BY JS.step_id ASC