--	http://ajaydwivedi.com/2016/12/log-all-activities-using-sp_whoisactive/

--	Verify Server Name
SELECT @@SERVERNAME as SrvName;

--	Step 01: Create Your @destination_table
USE DBA
GO

IF OBJECT_ID('dbo.WhoIsActive') IS NULL
BEGIN
	DECLARE @destination_table VARCHAR(4000) ;
	SET @destination_table = 'dbo.WhoIsActive';

	DECLARE @schema VARCHAR(4000) ;
	--	Specify all your proc parameters here
	EXEC master..sp_WhoIsActive @get_outer_command=1, @get_task_info=2
						,@get_locks=1 ,@get_plans=1 ,@find_block_leaders=1 ,@get_additional_info=1
						,@get_transaction_info=1
						,@return_schema = 1
						,@schema = @schema OUTPUT ;

	SET @schema = REPLACE(@schema, '<table_name>', @destination_table) ;

	PRINT @schema
	EXEC(@schema) ;
END
GO

--	Step 02: Add Computed Column to get TimeInMinutes
USE DBA
GO
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS as c WHERE c.TABLE_NAME = 'WhoIsActive' AND c.COLUMN_NAME = 'duration_minutes')
BEGIN
	ALTER TABLE dbo.WhoIsActive
		ADD duration_minutes AS DATEDIFF_BIG(MILLISECOND,start_time,collection_time)/1000/60;
END
GO

--	Step 03: Add a clustered Index
IF NOT EXISTS (select * from sys.indexes i where i.type_desc = 'CLUSTERED' and i.object_id = OBJECT_ID('dbo.WhoIsActive'))
BEGIN
	CREATE CLUSTERED INDEX [ci_WhoIsActive] ON [dbo].[WhoIsActive] ( [collection_time] ASC, session_id )
END
GO

--	Step 04: Add a Non-clustered Index
IF NOT EXISTS (select * from sys.indexes i where i.type_desc = 'NONCLUSTERED' and i.object_id = OBJECT_ID('dbo.WhoIsActive') and i.name = 'nci_WhoIsActive_blockings')
BEGIN
	CREATE NONCLUSTERED INDEX [nci_WhoIsActive_blockings] ON [dbo].[WhoIsActive]
	(	blocking_session_id, blocked_session_count, [collection_time] ASC, session_id)
	INCLUDE (login_name, [host_name], [database_name], [program_name])
	--ON [fg_nci]
END
GO

/*
--	Step 05: Test your Script
DECLARE	@destination_table VARCHAR(4000);
SET @destination_table = 'dbo.WhoIsActive';

EXEC dbo.sp_WhoIsActive @get_outer_command=1, @get_task_info=2
						,@get_locks=1 ,@get_plans=1 ,@find_block_leaders=1 ,@get_additional_info=1
						,@get_transaction_info=1
					,@destination_table = @destination_table ;
GO
*/

-- Step 06: Create SQL Agent Job
USE [msdb]
GO

/****** Object:  Job [(dba) Collect Metrics - WhoIsActive]    Script Date: 13-Sep-20 9:23:05 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 13-Sep-20 9:23:05 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics - WhoIsActive', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'This job will log activities using Adam Mechanic''s [sp_whoIsActive] stored procedure.

	Results are saved into DBA..WhoIsActive_ResultSets table.

	Job will run every 2 Minutes once started.', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Log activities with [sp_WhoIsActive]]    Script Date: 13-Sep-20 9:23:05 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Log activities with [sp_WhoIsActive]', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON;

DECLARE @is_test_alert bit = 0;
DECLARE @continuous_failure_count tinyint = 4;
DECLARE @failure_notification_delay_minutes int = 30;
DECLARE @operator_2_notify varchar(255) = ''DBA'';
DECLARE @mail_cc varchar(2000);

-- Variables for Try/Catch Block
DECLARE	@_errorNumber int,
				@_errorSeverity int,
				@_errorState int,
				@_errorLine int,
				@_errorMessage nvarchar(4000);

BEGIN TRY
	DECLARE	@destination_table VARCHAR(4000);
	SET @destination_table = ''dbo.WhoIsActive'';

	EXEC dbo.sp_WhoIsActive @get_outer_command=1, @get_task_info=2
						,@get_locks=1 ,@get_plans=1 ,@find_block_leaders=1 ,@get_additional_info=1
						,@get_transaction_info=1
					,@destination_table = @destination_table ;
			
	update w
	set query_plan = qp.query_plan
	from dbo.WhoIsActive AS w
	join sys.dm_exec_requests as r
	on w.session_id = r.session_id and w.request_id = r.request_id
	outer apply sys.dm_exec_text_query_plan(r.plan_handle, r.statement_start_offset, r.statement_end_offset) as qp
	where w.collection_time = (select max(ri.collection_time) from dbo.WhoIsActive AS ri)
	and w.query_plan IS NULL and qp.query_plan is not null;
				
END TRY  -- Perform main logic inside Try/Catch
BEGIN CATCH
	DECLARE @_mail_to varchar(2000);
	DECLARE @_tableHTML  NVARCHAR(MAX);  
	DECLARE @_subject nvarchar(1000);
	DECLARE @_job_name nvarchar(500);
	DECLARE @_job_step_name nvarchar(500);
	DECLARE	@_job_step_id int;

	SELECT @_job_name = name FROM msdb.dbo.sysjobs WHERE job_id = CONVERT(uniqueidentifier, $(ESCAPE_NONE(JOBID)));
	--SET @_job_name = ''Test Job by Ajay'';
	SET @_job_step_id = $(ESCAPE_NONE(STEPID));
	SELECT @_job_step_name = step_name FROM msdb.dbo.sysjobsteps where job_id = CONVERT(uniqueidentifier, $(ESCAPE_NONE(JOBID))) and step_id = @_job_step_id;

	SET @_subject = ''[The job failed.] SQL Server Job System: ''''''+@_job_name+'''''' completed on \\''+@@SERVERNAME+''.''
	IF @is_test_alert = 1
		SET @_subject = ''TestAlert - ''+@_subject;

	SELECT @_errorNumber	 = Error_Number()
				,@_errorSeverity = Error_Severity()
				,@_errorState	 = Error_State()
				,@_errorLine	 = Error_Line()
				,@_errorMessage	 = Error_Message();

	SET @_tableHTML =
		N''Sql Agent job ''''''+@_job_name+'''''' has failed for step ''+CAST(@_job_step_id AS varchar)+'' - ''''''+ @_job_step_name +'''''' @''+ CONVERT(nvarchar(30),getdate(),121) +''.''+
		N''<br><br>Error Number: '' + convert(varchar, @_errorNumber) + 
		N''<br>Line Number: '' + convert(varchar, @_errorLine) +
		N''<br>Error Message: <br>"'' + @_errorMessage + ''"'' +
		N''<br><br>Kindly resolve the job failure based on above error message.'';

	select @_mail_to = email_address from msdb.dbo.sysoperators where name = @operator_2_notify;

	IF 1 = 1 /* Logic for @failure_notification_delay_minutes & @continuous_failure_count */
	BEGIN
			EXEC msdb.dbo.sp_send_dbmail
							@recipients = @_mail_to,
							@copy_recipients = @mail_cc,
							--@profile_name = @@SERVERNAME,
							@subject = @_subject,
							@body = @_tableHTML,
							@body_format = ''HTML'';
	END
	select 12/0;
END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(dba) Collect Metrics - WhoIsActive', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=2, 
		@freq_subday_interval=100, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200913, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'a505e864-2f0d-4f61-9ebe-100fe9fc9f0c'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


USE [msdb]
GO

/****** Object:  Job [(dba) Collect Metrics - Purge WhoIsActive]    Script Date: 13-Sep-20 9:24:33 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [DBA]    Script Date: 13-Sep-20 9:24:33 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'DBA' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'DBA'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics - Purge WhoIsActive', 
		@enabled=1, 
		@notify_level_eventlog=2, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Cleanup job to clear data older than 60 days

	SET NOCOUNT ON;
	delete from dbo.WhoIsActive
		where collection_time <= DATEADD(DD,-60,GETDATE())', 
		@category_name=N'DBA', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'DBA', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge-Data-Older-Than-60-Days]    Script Date: 13-Sep-20 9:24:33 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge-Data-Older-Than-60-Days', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=1, 
		@retry_interval=7, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

declare @r int = 1;

while @r > 0
begin
	delete top (100000) from dbo.WhoIsActive
	where collection_time <= DATEADD(DD,-60,GETDATE())

	set @r = @@ROWCOUNT;
end
', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(dba) Collect Metrics - Purge WhoIsActive', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=34, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20190408, 
		@active_end_date=99991231, 
		@active_start_time=180000, 
		@active_end_time=235959, 
		@schedule_uid=N'8f0b13cd-1933-4061-9a79-3f7175abea97'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO