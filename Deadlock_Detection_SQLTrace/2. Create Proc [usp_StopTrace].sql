USE [DBA]
GO

ALTER PROCEDURE [dbo].[usp_StopTrace] @p_TracePath varchar(255), @p_JobName VARCHAR(125) = NULL
AS
BEGIN
	/*	Created By:			Ajay Dwivedi
		Created Date:		14-Sep-2018
	*/

	SET NOCOUNT ON;
	DECLARE @traceID int;

	--	If JobName is provided
	IF @p_JobName IS NOT NULL
	BEGIN
		IF EXISTS (
						SELECT *
						FROM msdb.dbo.sysjobactivity ja 
						LEFT JOIN msdb.dbo.sysjobhistory jh 
							ON ja.job_history_id = jh.instance_id
						JOIN msdb.dbo.sysjobs j 
						ON ja.job_id = j.job_id
						JOIN msdb.dbo.sysjobsteps js
							ON ja.job_id = js.job_id
							AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
						WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
						AND start_execution_date is not null
						AND stop_execution_date is null
						AND LTRIM(RTRIM(j.name)) = @p_JobName
		)
		BEGIN -- If Job is running
			PRINT 'Job is currently running. So can''t stop the Trace.';
		END
		ELSE
		BEGIN -- Stop the Trace if Job has finished
			if exists (select * from sys.traces t where t.path = @p_TracePath and status = 1)
			begin	-- Trace is running, Stop it			
				select @traceID = id from sys.traces t where t.path = @p_TracePath  and status = 1;
				exec sp_trace_setstatus @traceID, 0;

				print 'Trace stopped as job has finished';
			end
			else
				print 'Job and Trace both not running';
		END
	END
	ELSE
	BEGIN -- If no Job Name is passed, then simply disable Trace
		if exists (select * from sys.traces t where t.path = @p_TracePath and status = 1)
		begin
			select @traceID = id from sys.traces t where t.path = @p_TracePath and status = 1;
			exec sp_trace_setstatus @traceID, 0;
			print 'Trace stopped.';
		end
		else
			print 'Trace not running.';
	END
END -- Procedure
GO

--EXEC DBA..[usp_StopTrace] @p_TracePath = 'E:\DBA\SQLTrace\MSI_Laptop_10Sep2018_0143PM.trc', 
--						@p_JobName = 'Update Employee Salary - 2 Minutes'