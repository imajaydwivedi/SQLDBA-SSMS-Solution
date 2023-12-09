USE [msdb]
GO

/****** Object:  Job [(dba) Collect Metrics]    Script Date: 16-Sep-20 4:20:03 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 16-Sep-20 4:20:03 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Collect CPU/Memory metrics', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Collect Metrics - dm_os_sys_memory]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Collect Metrics - dm_os_sys_memory', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
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
	exec DBA..usp_collect_performance_metrics @metrics = ''dm_os_sys_memory'';
	--select 12/0
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

END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;
', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Collect Metrics - dm_os_process_memory]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Collect Metrics - dm_os_process_memory', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
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
	exec DBA..usp_collect_performance_metrics @metrics = ''dm_os_process_memory'';
	--select 12/0
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

END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;
', 
		@database_name=N'master', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Collect Metrics - dm_os_performance_counters]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Collect Metrics - dm_os_performance_counters', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
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
	exec DBA..usp_collect_performance_metrics @metrics = ''dm_os_performance_counters'';
	--select 12/0
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

END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;
', 
		@database_name=N'master', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Collect Metrics - dm_os_ring_buffers]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Collect Metrics - dm_os_ring_buffers', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
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
	exec msdb..sp_start_job @job_name = ''(dba) Collect Metrics - dm_os_ring_buffers''
	--select 12/0
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

END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;
', 
		@database_name=N'master', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Collect Metrics - dm_os_performance_counters_sampling]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Collect Metrics - dm_os_performance_counters_sampling', 
		@step_id=5, 
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
	exec msdb..sp_start_job @job_name = ''(dba) Collect Metrics - dm_os_performance_counters_sampling'';
	--select 12/0
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

END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;
', 
		@database_name=N'master', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(dba) Collect Performance Metrics - 2 - 01', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=2, 
		@freq_subday_interval=10, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200815, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'12a61bc4-5fa1-47cf-b68b-a1b628d665f4'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

/****** Object:  Job [(dba) Collect Metrics - dm_os_memory_clerks]    Script Date: 16-Sep-20 4:20:03 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 16-Sep-20 4:20:03 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics - dm_os_memory_clerks', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Collect [dm_os_memory_clerks]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Collect [dm_os_memory_clerks]', 
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
	exec dbo.usp_collect_performance_metrics @metrics = ''dm_os_memory_clerks'';
	--select 12/0
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

END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;
', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(dba) Collect Metrics - dm_os_memory_clerks', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=2, 
		@freq_subday_interval=30, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200907, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'7ab64b8a-75b6-40a9-a3a2-f81be1b476d5'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

/****** Object:  Job [(dba) Collect Metrics - dm_os_performance_counters_deprecated_features]    Script Date: 16-Sep-20 4:20:03 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 16-Sep-20 4:20:03 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics - dm_os_performance_counters_deprecated_features', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Collect Metrics - Deprecated Features]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Collect Metrics - Deprecated Features', 
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
	exec DBA..usp_collect_performance_metrics @metrics = ''dm_os_performance_counters_deprecated_features'';
	--select 12/0
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

END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;
', 
		@database_name=N'master', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(db) Collect Metrics - dm_os_performance_counters_deprecated_features', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=4, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200823, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'4caf120c-46ba-4dc7-839c-561628435bfe'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

/****** Object:  Job [(dba) Collect Metrics - dm_os_performance_counters_sampling]    Script Date: 16-Sep-20 4:20:03 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 16-Sep-20 4:20:03 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics - dm_os_performance_counters_sampling', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [(dba) Collect Metrics]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'(dba) Collect Metrics', 
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
	exec DBA..usp_collect_performance_metrics @metrics = ''dm_os_performance_counters_sampling'';
	--select 12/0
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

END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;
', 
		@database_name=N'master', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

/****** Object:  Job [(dba) Collect Metrics - dm_os_ring_buffers]    Script Date: 16-Sep-20 4:20:03 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 16-Sep-20 4:20:03 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics - dm_os_ring_buffers', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Collect CPU/Memory metrics', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Collect-Metrics - dm_os_ring_buffers]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Collect-Metrics - dm_os_ring_buffers', 
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
	exec DBA..usp_collect_performance_metrics @metrics = ''dm_os_ring_buffers'';
	--select 12/0
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

END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

/****** Object:  Job [(dba) Collect Metrics - dm_os_sys_info]    Script Date: 16-Sep-20 4:20:03 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 16-Sep-20 4:20:03 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics - dm_os_sys_info', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Collect SqlServer start time', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Collect Metrics - dm_os_sys_info]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Collect Metrics - dm_os_sys_info', 
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
	INSERT INTO DBA.dbo.dm_os_sys_info
	SELECT collection_time = getdate(), 
			server_name = @@SERVERNAME, 
			sqlserver_start_time, 
			wait_stats_cleared_time = ws.[Date/TimeCleared],
			cpu_count, physical_memory_kb, max_workers_count, virtual_machine_type, softnuma_configuration_desc, socket_count, cores_per_socket, numa_node_count
			--,WS.*
	--INTO DBA..dm_os_sys_info
	FROM sys.dm_os_sys_info as si
	OUTER APPLY
		(	SELECT	[wait_type],
					[wait_time_ms],
					[Date/TimeCleared] = CAST(DATEADD(ms,-[wait_time_ms],getdate()) as smalldatetime),
					CASE
					WHEN [wait_time_ms] < 1000 THEN CAST([wait_time_ms] AS VARCHAR(15)) + '' ms''
					WHEN [wait_time_ms] between 1000 and 60000 THEN CAST(([wait_time_ms]/1000) AS VARCHAR(15)) + '' seconds''
					WHEN [wait_time_ms] between 60001 and 3600000 THEN CAST(([wait_time_ms]/60000) AS VARCHAR(15)) + '' minutes''
					WHEN [wait_time_ms] between 3600001 and 86400000 THEN CAST(([wait_time_ms]/3600000) AS VARCHAR(15)) + '' hours''
					WHEN [wait_time_ms] > 86400000 THEN CAST(([wait_time_ms]/86400000) AS VARCHAR(15)) + '' days''
			END [TimeSinceCleared]
			FROM [sys].[dm_os_wait_stats]
			WHERE [wait_type] = ''SQLTRACE_INCREMENTAL_FLUSH_SLEEP''
		) AS ws
	WHERE NOT EXISTS (select * from DBA.dbo.dm_os_sys_info as i where i.sqlserver_start_time = si.sqlserver_start_time and i.wait_stats_cleared_time = ws.[Date/TimeCleared]);
	--select 12/0
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

END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;
', 
		@database_name=N'master', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(dba) Collect Metrics - dm_os_sys_info', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=2, 
		@freq_subday_interval=10, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200824, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'8d73cb10-d879-429a-975e-5ee1388326ad'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

/****** Object:  Job [(dba) Collect Metrics - NonSqlServer Perfmon Counters]    Script Date: 16-Sep-20 4:20:03 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 16-Sep-20 4:20:03 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics - NonSqlServer Perfmon Counters', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'powershell.exe -ExecutionPolicy Bypass .  ''D:\\MSSQL15.MSSQLSERVER\\MSSQL\Perfmon\perfmon-collector-push-to-sqlserver.ps1'';

https://docs.microsoft.com/en-us/windows/win32/perfctrs/counterdata?redirectedfrom=MSDN', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [truncate table [dbo].[CounterData]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'truncate table [dbo].[CounterData]', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
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
	if not exists (select * from [dbo].[DisplayToID] where RunID = 0)
	begin
		truncate table [dbo].[CounterData];
		truncate table [dbo].[CounterDetails];
	end
	--select 12/0
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

END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [NonSqlServer Perfmon Counters]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'NonSqlServer Perfmon Counters', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=N'powershell.exe -ExecutionPolicy Bypass .  ''D:\\MSSQL15.MSSQLSERVER\\MSSQL\Perfmon\perfmon-collector-push-to-sqlserver.ps1'';', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Populate dbo.dm_os_performance_counters_nonsql]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Populate dbo.dm_os_performance_counters_nonsql', 
		@step_id=3, 
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
	INSERT into dbo.dm_os_performance_counters_nonsql
	(collection_time, server_name, [object_name], counter_name, instance_name, cntr_value, cntr_type, id)
	select *
	from (
	select	collection_time = p2l.local_time
			,server_name = REPLACE(MachineName,''\\'','''')
			,[object_name] = dtls.ObjectName
			,counter_name = dtls.CounterName
			,instance_name = dtls.InstanceName
			,cntr_value = AVG(CounterValue)
			,cntr_type = dtls.CounterType
			,id = ROW_NUMBER()OVER(PARTITION BY p2l.local_time, ObjectName, CounterName ORDER BY  InstanceName, SYSDATETIME())
	FROM dbo.CounterData as dt -- GUID, CounterID, RecordIndex
	JOIN dbo.CounterDetails as dtls ON dtls.CounterID = dt.CounterID
	OUTER APPLY dbo.perfmon2local(dt.CounterDateTime) as p2l
	GROUP BY p2l.local_time, REPLACE(MachineName,''\\'',''''), 
					dtls.ObjectName, dtls.CounterName, dtls.InstanceName, dtls.CounterType
	) as pc
	WHERE NOT EXISTS (SELECT * FROM dbo.dm_os_performance_counters_nonsql epc 
						WHERE epc.collection_time = pc.collection_time and epc.object_name = pc.object_name
							and epc.counter_name = pc.counter_name and epc.id = pc.id
							--and epc.instance_name = pc.instance_name
					)
			--AND p2l.local_time = ''2020-09-11 08:00:35.4200000'' and ObjectName = ''LogicalDisk'' and CounterName = ''Current Disk Queue Length''
	ORDER BY collection_time, server_name, [object_name], counter_name;

	update [dbo].[DisplayToID]
	set RunID = 1
	where RunID = 0;
	--select 12/0
END TRY  -- Perform main logic inside Try/Catch
BEGIN CATCH
	DECLARE @_mail_to varchar(2000);
	DECLARE @_tableHTML  NVARCHAR(MAX);  
	DECLARE @_subject nvarchar(1000);
	DECLARE @_job_name nvarchar(500);
	DECLARE @_job_step_name nvarchar(500);
	DECLARE	@_job_step_id int;

	SELECT @_job_name = name FROM msdb.dbo.sysjobs WHERE job_id = CONVERT(uniqueidentifier, $(ESCAPE_NONE(JOBID)));
	--SET @_job_name = ''(dba) Collect Metrics - NonSqlServer Perfmon Counters'';
	SET @_job_step_id = $(ESCAPE_NONE(STEPID));
	--SET @_job_step_id = 1;
	SELECT @_job_step_name = step_name FROM msdb.dbo.sysjobsteps where job_id = CONVERT(uniqueidentifier, $(ESCAPE_NONE(JOBID))) and step_id = @_job_step_id;
	--SET @_job_step_name = ''Some Step_Name'';

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

END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;
', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(dba) Collect Metrics - NonSqlServer Perfmon Counters', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=2, 
		@freq_subday_interval=20, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200823, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'aaf78c03-6d6b-46c6-81ca-21d6b32ac508'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

/****** Object:  Job [(dba) Collect Metrics - Purge Aggregated Tables]    Script Date: 16-Sep-20 4:20:03 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 16-Sep-20 4:20:03 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics - Purge Aggregated Tables', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[dm_os_memory_clerks_aggregated]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[dm_os_memory_clerks_aggregated]', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[dm_os_memory_clerks_aggregated] */

set nocount on;
declare @retention_days int;
set @retention_days = 120; -- 15 active days -> 90 cool aggregated period -> 365 archive period

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (100000) [dbo].[dm_os_memory_clerks_aggregated] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[dm_os_performance_counters_aggregated_90days]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[dm_os_performance_counters_aggregated_90days]', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[dm_os_performance_counters_aggregated_90days] */
set nocount on;
set xact_abort on;

-- Set config variables
declare @retention_days int = 35; -- 15 active days + 90 days of retention
declare @time_interval_minutes tinyint = 60;

-- declare local variables
declare @r int = 1;
declare @date_filter date;
declare @date_filter_lower datetime2; -- filter for deleting data in chunks
declare @date_filter_upper datetime2; -- filter for deleting data in chunks

-- create table for storing deleted data for aggregation
if OBJECT_ID(''tempdb..#dm_os_performance_counters'') is not null
	drop table #dm_os_performance_counters;
CREATE TABLE #dm_os_performance_counters
(
	[collection_time] [datetime2] NOT NULL DEFAULT GETDATE(),
	[server_name] varchar(256) NOT NULL DEFAULT @@SERVERNAME,
	[object_name] [nvarchar](128) NOT NULL,
	[counter_name] [nvarchar](128) NOT NULL,
	[instance_name] [nvarchar](128) NULL,
	[cntr_value] [bigint] NOT NULL,
	[cntr_type] [int] NOT NULL,
	[id] smallint NOT NULL
);

set @date_filter = CONVERT(date,DATEADD(day,-@retention_days,GETDATE()));
select @date_filter_lower = dbo.aggregate_time(min(collection_time),@time_interval_minutes*2) from [dbo].[dm_os_performance_counters_aggregated_90days] where collection_time < @date_filter;
set @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_lower);


while @r > 0 or exists (select * from [dbo].[dm_os_performance_counters_aggregated_90days] where collection_time < @date_filter)
begin
	truncate table #dm_os_performance_counters;

	delete [dbo].[dm_os_performance_counters_aggregated_90days]
	output deleted.*
	into #dm_os_performance_counters
	where collection_time < @date_filter
		and (collection_time >= @date_filter_lower and collection_time < @date_filter_upper);

	set @r = @@ROWCOUNT;

	if @r > 0
	begin
		insert [dbo].[dm_os_performance_counters_aggregated_1year]
		select	[collection_time] = convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)),
				server_name, [object_name], counter_name, instance_name,
				cntr_value = AVG(cntr_value),
				cntr_type,
				id = ROW_NUMBER()OVER(ORDER BY GETDATE())
		from #dm_os_performance_counters as omc
		group by convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)), 
				server_name, [object_name], counter_name, instance_name, cntr_type

		print cast(@@ROWCOUNT as varchar)+ '' rows inserted into aggregated table'';
	end

	select @date_filter_lower = @date_filter_upper, @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_upper);
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[dm_os_performance_counters_aggregated_1year]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[dm_os_performance_counters_aggregated_1year]', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[dm_os_performance_counters_aggregated_1year] */

set nocount on;
declare @retention_days int;
set @retention_days = 120; -- 15 active days -> 90 aggregated period -> 365 days of total archive period

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (100000) [dbo].[dm_os_performance_counters_aggregated_1year] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[dm_os_performance_counters_nonsql_aggregated_90days]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[dm_os_performance_counters_nonsql_aggregated_90days]', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[dm_os_performance_counters_nonsql_aggregated_90days] */
set nocount on;
set xact_abort on;

IF NOT EXISTS (select * from sys.objects where object_id = OBJECT_ID(''dbo.dm_os_performance_counters_nonsql_aggregated_90days'') AND type_desc = ''USER_TABLE'')
	RETURN;

-- Set config variables
declare @retention_days int = 35; -- 15 active days + 90 days of retention
declare @time_interval_minutes tinyint = 60;

-- declare local variables
declare @r int = 1;
declare @date_filter date;
declare @date_filter_lower datetime2; -- filter for deleting data in chunks
declare @date_filter_upper datetime2; -- filter for deleting data in chunks

-- create table for storing deleted data for aggregation
if OBJECT_ID(''tempdb..#dm_os_performance_counters'') is not null
	drop table #dm_os_performance_counters;
CREATE TABLE #dm_os_performance_counters
(
	[collection_time] [datetime2] NOT NULL DEFAULT GETDATE(),
	[server_name] varchar(256) NOT NULL DEFAULT @@SERVERNAME,
	[object_name] [nvarchar](128) NOT NULL,
	[counter_name] [nvarchar](128) NOT NULL,
	[instance_name] [nvarchar](128) NULL,
	[cntr_value] [bigint] NOT NULL,
	[cntr_type] [int] NOT NULL,
	[id] smallint NOT NULL
);

set @date_filter = CONVERT(date,DATEADD(day,-@retention_days,GETDATE()));
select @date_filter_lower = dbo.aggregate_time(min(collection_time),@time_interval_minutes*2) from [dbo].[dm_os_performance_counters_nonsql_aggregated_90days] where collection_time < @date_filter;
set @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_lower);


while @r > 0 or exists (select * from [dbo].[dm_os_performance_counters_nonsql_aggregated_90days] where collection_time < @date_filter)
begin
	truncate table #dm_os_performance_counters;

	delete [dbo].[dm_os_performance_counters_nonsql_aggregated_90days]
	output deleted.*
	into #dm_os_performance_counters
	where collection_time < @date_filter
		and (collection_time >= @date_filter_lower and collection_time < @date_filter_upper);

	set @r = @@ROWCOUNT;

	if @r > 0
	begin
		insert [dbo].[dm_os_performance_counters_nonsql_aggregated_1year]
		select	[collection_time] = convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)),
				server_name, [object_name], counter_name, instance_name,
				cntr_value = AVG(cntr_value),
				cntr_type,
				id = ROW_NUMBER()OVER(ORDER BY GETDATE())
		from #dm_os_performance_counters as omc
		group by convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)), 
				server_name, [object_name], counter_name, instance_name, cntr_type

		print cast(@@ROWCOUNT as varchar)+ '' rows inserted into aggregated table'';
	end

	select @date_filter_lower = @date_filter_upper, @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_upper);
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[dm_os_performance_counters_nonsql_aggregated_1year]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[dm_os_performance_counters_nonsql_aggregated_1year]', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[dm_os_performance_counters_nonsql_aggregated_1year] */

set nocount on;

IF NOT EXISTS (select * from sys.objects where object_id = OBJECT_ID(''dbo.dm_os_performance_counters_nonsql_aggregated_1year'') AND type_desc = ''USER_TABLE'')
	RETURN;

declare @retention_days int;
set @retention_days = 120; -- 15 active days -> 90 aggregated period -> 365 days of total archive period

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (100000) [dbo].[dm_os_performance_counters_nonsql_aggregated_1year] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[dm_os_process_memory_aggregated]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[dm_os_process_memory_aggregated]', 
		@step_id=6, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[dm_os_process_memory_aggregated] */

set nocount on;
declare @retention_days int;
set @retention_days = 120; -- 15 active days -> 90 aggregated period -> 365 days of total archive period

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (100000) [dbo].[dm_os_process_memory_aggregated] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[dm_os_ring_buffers_aggregated]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[dm_os_ring_buffers_aggregated]', 
		@step_id=7, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[dm_os_ring_buffers_aggregated] */

set nocount on;
declare @retention_days int;
set @retention_days = 120; -- 15 active days -> 90 aggregated period -> 365 days of total archive period

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (10000) [dbo].[dm_os_ring_buffers_aggregated] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[dm_os_sys_memory_aggregated]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[dm_os_sys_memory_aggregated]', 
		@step_id=8, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[dm_os_sys_memory_aggregated] */

set nocount on;
declare @retention_days int;
set @retention_days = 120; -- 15 active days -> 90 aggregated period -> 365 days of total archive period

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (100000) [dbo].[dm_os_sys_memory_aggregated] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[WaitStats_aggregated]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[WaitStats_aggregated]', 
		@step_id=9, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[WaitStats_aggregated] */

set nocount on;
declare @retention_days int;
set @retention_days = 120; -- 15 active days -> 90 aggregated period -> 365 days of total archive period

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (100000) [dbo].[WaitStats_aggregated] where Collection_Time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

/****** Object:  Job [(dba) Collect Metrics - Purge Perfmon Files]    Script Date: 16-Sep-20 4:20:03 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 16-Sep-20 4:20:03 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics - Purge Perfmon Files', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Delete PerfMon Files]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Delete PerfMon Files', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=N'powershell.exe -ExecutionPolicy Bypass .  ''D:\\MSSQL15.MSSQLSERVER\\MSSQL\Perfmon\perfmon-remove-imported-files.ps1'';', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(dba) Collect Metrics - Purge Perfmon Files', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=4, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200907, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'b32218a0-5ba2-4fa6-8d86-6b7faa71d6f3'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

/****** Object:  Job [(dba) Collect Metrics - Purge Regular Tables]    Script Date: 16-Sep-20 4:20:03 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 16-Sep-20 4:20:03 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics - Purge Regular Tables', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[dm_os_memory_clerks]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[dm_os_memory_clerks]', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[dm_os_memory_clerks] */

set nocount on;
set xact_abort on;

-- Set config variables
declare @retention_days int = 7;
declare @time_interval_minutes tinyint = 10;

-- declare local variables
declare @r int = 1;
declare @date_filter date;
declare @date_filter_lower datetime2; -- filter for deleting data in chunks
declare @date_filter_upper datetime2; -- filter for deleting data in chunks

-- create table for storing deleted data for aggregation
if OBJECT_ID(''tempdb..#dm_os_memory_clerks'') is not null
	drop table #dm_os_memory_clerks;
create table #dm_os_memory_clerks
(
	[collection_time] [datetime2] NOT NULL DEFAULT GETDATE(),
	[memory_clerk] [nvarchar](60) NOT NULL,
	[size_mb] [bigint] NULL
);

set @date_filter = CONVERT(date,DATEADD(day,-@retention_days,GETDATE()));
select @date_filter_lower = dbo.aggregate_time(min(collection_time),@time_interval_minutes*2) from [dbo].[dm_os_memory_clerks] where collection_time < @date_filter;
set @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_lower);

while @r > 0 or exists (select * from [dbo].[dm_os_memory_clerks] where collection_time < @date_filter)
begin
	truncate table #dm_os_memory_clerks;

	delete [dbo].[dm_os_memory_clerks]
	output deleted.collection_time, deleted.memory_clerk, deleted.size_mb
	into #dm_os_memory_clerks
	where collection_time < @date_filter
		and (collection_time >= @date_filter_lower and collection_time < @date_filter_upper);
	
	set @r = @@ROWCOUNT;

	if @r > 0
	begin
		insert [dbo].[dm_os_memory_clerks_aggregated]
		select	[collection_time] = convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)),
				[memory_clerk], 
				size_mb = AVG(size_mb)
		from #dm_os_memory_clerks as omc
		group by convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)), [memory_clerk];

		print cast(@@ROWCOUNT as varchar)+ '' rows inserted into aggregated table'';
	end

	select @date_filter_lower = @date_filter_upper, @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_upper);
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[dm_os_performance_counters]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[dm_os_performance_counters]', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[dm_os_performance_counters] */
set nocount on;
set xact_abort on;

-- Set config variables
declare @retention_days int = 7;
declare @time_interval_minutes tinyint = 10;

-- declare local variables
declare @r int = 1;
declare @date_filter date;
declare @date_filter_lower datetime2; -- filter for deleting data in chunks
declare @date_filter_upper datetime2; -- filter for deleting data in chunks

-- create table for storing deleted data for aggregation
if OBJECT_ID(''tempdb..#dm_os_performance_counters'') is not null
	drop table #dm_os_performance_counters;
CREATE TABLE #dm_os_performance_counters
(
	[collection_time] [datetime2] NOT NULL DEFAULT GETDATE(),
	[server_name] varchar(256) NOT NULL DEFAULT @@SERVERNAME,
	[object_name] [nvarchar](128) NOT NULL,
	[counter_name] [nvarchar](128) NOT NULL,
	[instance_name] [nvarchar](128) NULL,
	[cntr_value] [bigint] NOT NULL,
	[cntr_type] [int] NOT NULL,
	[id] smallint NOT NULL
);

set @date_filter = CONVERT(date,DATEADD(day,-@retention_days,GETDATE()));
select @date_filter_lower = dbo.aggregate_time(min(collection_time),@time_interval_minutes*2) from [dbo].[dm_os_performance_counters] where collection_time < @date_filter;
set @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_lower);


while @r > 0 or exists (select * from [dbo].[dm_os_performance_counters] where collection_time < @date_filter)
begin
	truncate table #dm_os_performance_counters;

	delete [dbo].[dm_os_performance_counters]
	output deleted.*
	into #dm_os_performance_counters
	where collection_time < @date_filter
		and (collection_time >= @date_filter_lower and collection_time < @date_filter_upper);

	set @r = @@ROWCOUNT;

	if @r > 0
	begin
		insert [dbo].[dm_os_performance_counters_aggregated_90days]
		select	[collection_time] = convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)),
				server_name, [object_name], counter_name, instance_name,
				cntr_value = AVG(cntr_value),
				cntr_type,
				id = ROW_NUMBER()OVER(ORDER BY GETDATE())
		from #dm_os_performance_counters as omc
		group by convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)), 
				server_name, [object_name], counter_name, instance_name, cntr_type

		print cast(@@ROWCOUNT as varchar)+ '' rows inserted into aggregated table'';
	end

	select @date_filter_lower = @date_filter_upper, @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_upper);
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[dm_os_performance_counters_nonsql]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[dm_os_performance_counters_nonsql]', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[dm_os_performance_counters_nonsql] */

set nocount on;
set xact_abort on;
SET QUOTED_IDENTIFIER OFF;

declare @sql varchar(max);
set @sql = "
-- Set config variables
declare @retention_days int = 7;
declare @time_interval_minutes tinyint = 10;

-- declare local variables
declare @r int = 1;
declare @date_filter date;
declare @date_filter_lower datetime2; -- filter for deleting data in chunks
declare @date_filter_upper datetime2; -- filter for deleting data in chunks

-- create table for storing deleted data for aggregation
if OBJECT_ID(''tempdb..#dm_os_performance_counters_nonsql_aggregated'') is not null
	drop table #dm_os_performance_counters_nonsql_aggregated;
CREATE TABLE #dm_os_performance_counters_nonsql_aggregated
(
	[collection_time] [datetime2] NOT NULL,
	[server_name] [varchar](256) NOT NULL,
	[object_name] [nvarchar](128) NOT NULL,
	[counter_name] [nvarchar](128) NOT NULL,
	[instance_name] [nvarchar](128) NULL,
	[cntr_value] [bigint] NOT NULL,
	[cntr_type] [int] NOT NULL,
	[id] [smallint] NOT NULL
);

set @date_filter = CONVERT(date,DATEADD(day,-@retention_days,GETDATE()));
select @date_filter_lower = dbo.aggregate_time(min(collection_time),@time_interval_minutes*2) from [dbo].[dm_os_performance_counters_nonsql] where collection_time < @date_filter;
set @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_lower);

while @r > 0 or exists (select * from [dbo].[dm_os_performance_counters_nonsql] where collection_time < @date_filter)
begin
	truncate table #dm_os_performance_counters_nonsql_aggregated;

	delete [dbo].[dm_os_performance_counters_nonsql]
	output deleted.*
	into #dm_os_performance_counters_nonsql_aggregated
	where collection_time < @date_filter
		and (collection_time >= @date_filter_lower and collection_time < @date_filter_upper);

	set @r = @@ROWCOUNT;

	if @r > 0
	begin
		insert [dbo].[dm_os_performance_counters_nonsql_aggregated_90days]
		select	[collection_time] = convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)),
				server_name, [object_name], counter_name, instance_name,
				cntr_value = AVG(cntr_value),
				cntr_type,
				id = ROW_NUMBER()OVER(ORDER BY GETDATE())
		from #dm_os_performance_counters_nonsql_aggregated as omc
		group by convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)), 
				server_name, [object_name], counter_name, instance_name, cntr_type

		print cast(@@ROWCOUNT as varchar)+ '' rows inserted into aggregated table'';
	end

	select @date_filter_lower = @date_filter_upper, @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_upper);
end
"

IF EXISTS (select * from sys.objects where object_id = OBJECT_ID(''dbo.dm_os_performance_counters_nonsql'') AND type_desc = ''USER_TABLE'')
	exec (@sql);
', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[dm_os_process_memory]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[dm_os_process_memory]', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[dm_os_process_memory] */

set nocount on;
set xact_abort on;

-- Set config variables
declare @retention_days int = 7;
declare @time_interval_minutes tinyint = 10;

-- declare local variables
declare @r int = 1;
declare @date_filter date;
declare @date_filter_lower datetime2; -- filter for deleting data in chunks
declare @date_filter_upper datetime2; -- filter for deleting data in chunks

-- create table for storing deleted data for aggregation
if OBJECT_ID(''tempdb..#dm_os_process_memory_aggregated'') is not null
	drop table #dm_os_process_memory_aggregated;
CREATE TABLE #dm_os_process_memory_aggregated
(
	[collection_time] [datetime2] NOT NULL,
	[SQL Server Memory Usage (MB)] [bigint] NULL,
	[page_fault_count] [bigint] NOT NULL,
	[memory_utilization_percentage] [int] NOT NULL,
	[available_commit_limit_kb] [bigint] NOT NULL,
	[process_physical_memory_low] [bit] NOT NULL,
	[process_virtual_memory_low] [bit] NOT NULL,
	[SQL Server Locked Pages Allocation (MB)] [bigint] NULL,
	[SQL Server Large Pages Allocation (MB)] [bigint] NULL
);

set @date_filter = CONVERT(date,DATEADD(day,-@retention_days,GETDATE()));
select @date_filter_lower = dbo.aggregate_time(min(collection_time),@time_interval_minutes*2) from [dbo].[dm_os_process_memory] where collection_time < @date_filter;
set @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_lower);

while @r > 0 or exists (select * from [dbo].[dm_os_process_memory] where collection_time < @date_filter)
begin
	truncate table #dm_os_process_memory_aggregated;

	delete [dbo].[dm_os_process_memory]
	output deleted.*
	into #dm_os_process_memory_aggregated
	where collection_time < @date_filter
		and (collection_time >= @date_filter_lower and collection_time < @date_filter_upper);

	set @r = @@ROWCOUNT;

	if @r > 0
	begin
		insert [dbo].[dm_os_process_memory_aggregated]
		select	[collection_time] = convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)),
				[SQL Server Memory Usage (MB)] = AVG([SQL Server Memory Usage (MB)]),
				[page_fault_count] = AVG([page_fault_count]),
				[memory_utilization_percentage] = AVG([memory_utilization_percentage]),
				[available_commit_limit_kb] = AVG([available_commit_limit_kb]),
				[process_physical_memory_low] = AVG(CONVERT(TINYINT,[process_physical_memory_low])),
				[process_virtual_memory_low] = AVG(CONVERT(TINYINT,[process_virtual_memory_low])),
				[SQL Server Locked Pages Allocation (MB)] = AVG([SQL Server Locked Pages Allocation (MB)]),
				[SQL Server Large Pages Allocation (MB)] = AVG([SQL Server Large Pages Allocation (MB)])
		from #dm_os_process_memory_aggregated as opm
		group by convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes))

		print cast(@@ROWCOUNT as varchar)+ '' rows inserted into aggregated table'';
	end

	select @date_filter_lower = @date_filter_upper, @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_upper);
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[dm_os_ring_buffers]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[dm_os_ring_buffers]', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[dm_os_ring_buffers] */

set nocount on;
set xact_abort on;

-- Set config variables
declare @retention_days int = 7;
declare @time_interval_minutes tinyint = 10;

-- declare local variables
declare @r int = 1;
declare @date_filter date;
declare @date_filter_lower datetime2; -- filter for deleting data in chunks
declare @date_filter_upper datetime2; -- filter for deleting data in chunks

-- create table for storing deleted data for aggregation
if OBJECT_ID(''tempdb..#dm_os_ring_buffers_aggregated'') is not null
	drop table #dm_os_ring_buffers_aggregated;
CREATE TABLE #dm_os_ring_buffers_aggregated
(
	[collection_time] [datetime2] NOT NULL,
	[system_cpu_utilization] [int] NOT NULL,
	[sql_cpu_utilization] [int] NOT NULL
);

set @date_filter = CONVERT(date,DATEADD(day,-@retention_days,GETDATE()));
select @date_filter_lower = dbo.aggregate_time(min(collection_time),@time_interval_minutes*2) from [dbo].[dm_os_ring_buffers] where collection_time < @date_filter;
set @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_lower);

while @r > 0 or exists (select * from [dbo].[dm_os_ring_buffers] where collection_time < @date_filter)
begin
	truncate table #dm_os_ring_buffers_aggregated;

	delete [dbo].[dm_os_ring_buffers]
	output deleted.*
	into #dm_os_ring_buffers_aggregated
	where collection_time < @date_filter
		and (collection_time >= @date_filter_lower and collection_time < @date_filter_upper);

	set @r = @@ROWCOUNT;

	if @r > 0
	begin
		insert [dbo].[dm_os_ring_buffers_aggregated]
		select	[collection_time] = convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)),
				system_cpu_utilization = AVG(system_cpu_utilization),
				sql_cpu_utilization = AVG(sql_cpu_utilization)
		from #dm_os_ring_buffers_aggregated as opm
		group by convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes))

		print cast(@@ROWCOUNT as varchar)+ '' rows inserted into aggregated table'';
	end

	select @date_filter_lower = @date_filter_upper, @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_upper);
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[dm_os_sys_info]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[dm_os_sys_info]', 
		@step_id=6, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* No special Purging logic Required */

set nocount on;
declare @retention_days int;
set @retention_days = 365;

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (10000) [dbo].[dm_os_sys_info] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[dm_os_sys_memory]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[dm_os_sys_memory]', 
		@step_id=7, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[dm_os_sys_memory] */

set nocount on;
set xact_abort on;

-- Set config variables
declare @retention_days int = 7;
declare @time_interval_minutes tinyint = 10;

-- declare local variables
declare @r int = 1;
declare @date_filter date;
declare @date_filter_lower datetime2; -- filter for deleting data in chunks
declare @date_filter_upper datetime2; -- filter for deleting data in chunks

-- create table for storing deleted data for aggregation
if OBJECT_ID(''tempdb..#dm_os_sys_memory_aggregated'') is not null
	drop table #dm_os_sys_memory_aggregated;
CREATE TABLE #dm_os_sys_memory_aggregated
(
	[collection_time] [datetime2] NOT NULL,
	[server_name] [nvarchar](128) NOT NULL,
	[total_physical_memory_kb] [numeric](30, 2) NOT NULL,
	[available_physical_memory_kb] [numeric](30, 2) NOT NULL,
	[used_page_file_kb] [numeric](30, 2) NOT NULL,
	[system_cache_kb] [numeric](30, 2) NOT NULL,
	[free_memory_kb] [numeric](30, 2) NOT NULL,
	[system_memory_state_desc] [nvarchar](256) NOT NULL,
	[memory_usage_percentage] AS (cast(((total_physical_memory_kb-available_physical_memory_kb) * 100.0) / total_physical_memory_kb as numeric(20,2)))
);

set @date_filter = CONVERT(date,DATEADD(day,-@retention_days,GETDATE()));
select @date_filter_lower = dbo.aggregate_time(min(collection_time),@time_interval_minutes*2) from [dbo].[dm_os_sys_memory] where collection_time < @date_filter;
set @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_lower);

while @r > 0 or exists (select * from [dbo].[dm_os_sys_memory] where collection_time < @date_filter)
begin
	truncate table #dm_os_sys_memory_aggregated;

	delete [dbo].[dm_os_sys_memory]
	output deleted.collection_time, deleted.server_name, deleted.total_physical_memory_kb, deleted.available_physical_memory_kb, deleted.used_page_file_kb, deleted.system_cache_kb, deleted.free_memory_kb, deleted.system_memory_state_desc
	into #dm_os_sys_memory_aggregated
	where collection_time < @date_filter
		and (collection_time >= @date_filter_lower and collection_time < @date_filter_upper);

	set @r = @@ROWCOUNT;

	if @r > 0
	begin
		insert [dbo].[dm_os_sys_memory_aggregated]
		(collection_time, total_physical_memory_kb, available_physical_memory_kb, used_page_file_kb, system_cache_kb, free_memory_kb)
		select	[collection_time] = convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)),
				total_physical_memory_kb = AVG(total_physical_memory_kb),
				available_physical_memory_kb = AVG(available_physical_memory_kb),
				used_page_file_kb = AVG(used_page_file_kb),
				system_cache_kb = AVG(system_cache_kb),
				free_memory_kb = AVG(free_memory_kb)
		from #dm_os_sys_memory_aggregated as osm
		group by convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes))

		print cast(@@ROWCOUNT as varchar)+ '' rows inserted into aggregated table'';
	end

	select @date_filter_lower = @date_filter_upper, @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_upper);
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge [dbo].[WaitStats]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge [dbo].[WaitStats]', 
		@step_id=8, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Purge [dbo].[WaitStats] */

set nocount on;
set xact_abort on;

-- Set config variables
declare @retention_days int = 7;
declare @time_interval_minutes tinyint = 10;

-- declare local variables
declare @r int = 1;
declare @date_filter date;
declare @date_filter_lower datetime2; -- filter for deleting data in chunks
declare @date_filter_upper datetime2; -- filter for deleting data in chunks

-- create table for storing deleted data for aggregation
if OBJECT_ID(''tempdb..#WaitStats_aggregated'') is not null
	drop table #WaitStats_aggregated;
CREATE TABLE #WaitStats_aggregated
(
	[Collection_Time] [datetime2] NOT NULL,
	[RowNum] [smallint] NOT NULL,
	[WaitType] [nvarchar](120) NOT NULL,
	[Wait_S] [decimal](20, 2) NOT NULL,
	[Resource_S] [decimal](20, 2) NOT NULL,
	[Signal_S] [decimal](20, 2) NOT NULL,
	[WaitCount] [bigint] NOT NULL,
	[Percentage] [decimal](5, 2) NULL,
	[AvgWait_S] AS ([Wait_S]/[WaitCount]),
	[AvgRes_S] AS ([Resource_S]/[WaitCount]),
	[AvgSig_S] AS ([Signal_S]/[WaitCount]),
	[Help_URL] AS (CONVERT([xml],''https://www.sqlskills.com/help/waits/''+[WaitType]))
);

set @date_filter = CONVERT(date,DATEADD(day,-@retention_days,GETDATE()));
select @date_filter_lower = dbo.aggregate_time(min([Collection_Time]),@time_interval_minutes*2) from [dbo].[WaitStats] where [Collection_Time] < @date_filter;
set @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_lower);

--select [@date_filter] = @date_filter, [@date_filter_lower] = @date_filter_lower, [@date_filter_upper] = @date_filter_upper;

while @r > 0 or exists (select * from [dbo].[WaitStats] where [Collection_Time] < @date_filter)
begin
	truncate table #WaitStats_aggregated;

	delete [dbo].[WaitStats]
	output deleted.Collection_Time, deleted.RowNum, deleted.WaitType, deleted.Wait_S, deleted.Resource_S, deleted.Signal_S, deleted.WaitCount, deleted.Percentage
	into #WaitStats_aggregated
	where [Collection_Time] < @date_filter
		and ([Collection_Time] >= @date_filter_lower and [Collection_Time] < @date_filter_upper);

	set @r = @@ROWCOUNT;

	if @r > 0
	begin
		-- Insert 1st collection batch in the @time_interval_minutes range
		insert [dbo].[WaitStats_aggregated]
		(Collection_Time, RowNum, WaitType, Wait_S, Resource_S, Signal_S, WaitCount, Percentage)
		select	Collection_Time, RowNum, WaitType, Wait_S, Resource_S, Signal_S, WaitCount, Percentage
		from #WaitStats_aggregated as ws
		where [Collection_Time] in (select MIN(ag.Collection_Time) from #WaitStats_aggregated ag group by convert(smalldatetime,dbo.aggregate_time(ag.collection_time,@time_interval_minutes)) );

		print cast(@@ROWCOUNT as varchar)+ '' rows inserted into aggregated table'';
	end
	
	select @date_filter_lower = @date_filter_upper, @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_upper);
end
', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Start job [(dba) Collect Metrics - Purge Aggregated Tables]]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Start job [(dba) Collect Metrics - Purge Aggregated Tables]', 
		@step_id=9, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec msdb..sp_start_job @job_name = ''(dba) Collect Metrics - Purge Aggregated Tables'';', 
		@database_name=N'msdb', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(dba) Collect Metrics - Purge Aggregated Tables', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=4, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200823, 
		@active_end_date=99991231, 
		@active_start_time=180000, 
		@active_end_time=235959, 
		@schedule_uid=N'f68ed208-9e03-4fd6-a44f-fea2c99ad468'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

/****** Object:  Job [(dba) Collect Metrics - Purge WhoIsActive]    Script Date: 16-Sep-20 4:20:03 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [DBA]    Script Date: 16-Sep-20 4:20:03 PM ******/
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
/****** Object:  Step [Purge-Data-Older-Than-60-Days]    Script Date: 16-Sep-20 4:20:03 PM ******/
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

/****** Object:  Job [(dba) Collect Metrics - Wait Stats]    Script Date: 16-Sep-20 4:20:03 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 16-Sep-20 4:20:03 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics - Wait Stats', 
		@enabled=1, 
		@notify_level_eventlog=2, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Collect Metrics - Wait Stats]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Collect Metrics - Wait Stats', 
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
	-- Last updated February 26, 2019
	;WITH [Waits] AS (
		SELECT
			[wait_type],
			[wait_time_ms] / 1000.0 AS [WaitS],
			([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS],
			[signal_wait_time_ms] / 1000.0 AS [SignalS],
			[waiting_tasks_count] AS [WaitCount],
			100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],
			ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
		FROM sys.dm_os_wait_stats
		WHERE [wait_type] NOT IN (
			-- These wait types are almost 100% never a problem and so they are
			-- filtered out to avoid them skewing the results. Click on the URL
			-- for more information.
			N''BROKER_EVENTHANDLER'', -- https://www.sqlskills.com/help/waits/BROKER_EVENTHANDLER
			N''BROKER_RECEIVE_WAITFOR'', -- https://www.sqlskills.com/help/waits/BROKER_RECEIVE_WAITFOR
			N''BROKER_TASK_STOP'', -- https://www.sqlskills.com/help/waits/BROKER_TASK_STOP
			N''BROKER_TO_FLUSH'', -- https://www.sqlskills.com/help/waits/BROKER_TO_FLUSH
			N''BROKER_TRANSMITTER'', -- https://www.sqlskills.com/help/waits/BROKER_TRANSMITTER
			N''CHECKPOINT_QUEUE'', -- https://www.sqlskills.com/help/waits/CHECKPOINT_QUEUE
			N''CHKPT'', -- https://www.sqlskills.com/help/waits/CHKPT
			N''CLR_AUTO_EVENT'', -- https://www.sqlskills.com/help/waits/CLR_AUTO_EVENT
			N''CLR_MANUAL_EVENT'', -- https://www.sqlskills.com/help/waits/CLR_MANUAL_EVENT
			N''CLR_SEMAPHORE'', -- https://www.sqlskills.com/help/waits/CLR_SEMAPHORE
			N''CXCONSUMER'', -- https://www.sqlskills.com/help/waits/CXCONSUMER
			-- Maybe comment these four out if you have mirroring issues
			N''DBMIRROR_DBM_EVENT'', -- https://www.sqlskills.com/help/waits/DBMIRROR_DBM_EVENT
			N''DBMIRROR_EVENTS_QUEUE'', -- https://www.sqlskills.com/help/waits/DBMIRROR_EVENTS_QUEUE
			N''DBMIRROR_WORKER_QUEUE'', -- https://www.sqlskills.com/help/waits/DBMIRROR_WORKER_QUEUE
			N''DBMIRRORING_CMD'', -- https://www.sqlskills.com/help/waits/DBMIRRORING_CMD
			N''DIRTY_PAGE_POLL'', -- https://www.sqlskills.com/help/waits/DIRTY_PAGE_POLL
			N''DISPATCHER_QUEUE_SEMAPHORE'', -- https://www.sqlskills.com/help/waits/DISPATCHER_QUEUE_SEMAPHORE
			N''EXECSYNC'', -- https://www.sqlskills.com/help/waits/EXECSYNC
			N''FSAGENT'', -- https://www.sqlskills.com/help/waits/FSAGENT
			N''FT_IFTS_SCHEDULER_IDLE_WAIT'', -- https://www.sqlskills.com/help/waits/FT_IFTS_SCHEDULER_IDLE_WAIT
			N''FT_IFTSHC_MUTEX'', -- https://www.sqlskills.com/help/waits/FT_IFTSHC_MUTEX
			-- Maybe comment these six out if you have AG issues
			N''HADR_CLUSAPI_CALL'', -- https://www.sqlskills.com/help/waits/HADR_CLUSAPI_CALL
			N''HADR_FILESTREAM_IOMGR_IOCOMPLETION'', -- https://www.sqlskills.com/help/waits/HADR_FILESTREAM_IOMGR_IOCOMPLETION
			N''HADR_LOGCAPTURE_WAIT'', -- https://www.sqlskills.com/help/waits/HADR_LOGCAPTURE_WAIT
			N''HADR_NOTIFICATION_DEQUEUE'', -- https://www.sqlskills.com/help/waits/HADR_NOTIFICATION_DEQUEUE
			N''HADR_TIMER_TASK'', -- https://www.sqlskills.com/help/waits/HADR_TIMER_TASK
			N''HADR_WORK_QUEUE'', -- https://www.sqlskills.com/help/waits/HADR_WORK_QUEUE
			N''KSOURCE_WAKEUP'', -- https://www.sqlskills.com/help/waits/KSOURCE_WAKEUP
			N''LAZYWRITER_SLEEP'', -- https://www.sqlskills.com/help/waits/LAZYWRITER_SLEEP
			N''LOGMGR_QUEUE'', -- https://www.sqlskills.com/help/waits/LOGMGR_QUEUE
			N''MEMORY_ALLOCATION_EXT'', -- https://www.sqlskills.com/help/waits/MEMORY_ALLOCATION_EXT
			N''ONDEMAND_TASK_QUEUE'', -- https://www.sqlskills.com/help/waits/ONDEMAND_TASK_QUEUE
			N''PARALLEL_REDO_DRAIN_WORKER'', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_DRAIN_WORKER
			N''PARALLEL_REDO_LOG_CACHE'', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_LOG_CACHE
			N''PARALLEL_REDO_TRAN_LIST'', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_TRAN_LIST
			N''PARALLEL_REDO_WORKER_SYNC'', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_WORKER_SYNC
			N''PARALLEL_REDO_WORKER_WAIT_WORK'', -- https://www.sqlskills.com/help/waits/PARALLEL_REDO_WORKER_WAIT_WORK
			N''PREEMPTIVE_OS_FLUSHFILEBUFFERS'', -- https://www.sqlskills.com/help/waits/PREEMPTIVE_OS_FLUSHFILEBUFFERS
			N''PREEMPTIVE_XE_GETTARGETSTATE'', -- https://www.sqlskills.com/help/waits/PREEMPTIVE_XE_GETTARGETSTATE
			N''PWAIT_ALL_COMPONENTS_INITIALIZED'', -- https://www.sqlskills.com/help/waits/PWAIT_ALL_COMPONENTS_INITIALIZED
			N''PWAIT_DIRECTLOGCONSUMER_GETNEXT'', -- https://www.sqlskills.com/help/waits/PWAIT_DIRECTLOGCONSUMER_GETNEXT
			N''QDS_PERSIST_TASK_MAIN_LOOP_SLEEP'', -- https://www.sqlskills.com/help/waits/QDS_PERSIST_TASK_MAIN_LOOP_SLEEP
			N''QDS_ASYNC_QUEUE'', -- https://www.sqlskills.com/help/waits/QDS_ASYNC_QUEUE
			N''QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP'',
				-- https://www.sqlskills.com/help/waits/QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP
			N''QDS_SHUTDOWN_QUEUE'', -- https://www.sqlskills.com/help/waits/QDS_SHUTDOWN_QUEUE
			N''REDO_THREAD_PENDING_WORK'', -- https://www.sqlskills.com/help/waits/REDO_THREAD_PENDING_WORK
			N''REQUEST_FOR_DEADLOCK_SEARCH'', -- https://www.sqlskills.com/help/waits/REQUEST_FOR_DEADLOCK_SEARCH
			N''RESOURCE_QUEUE'', -- https://www.sqlskills.com/help/waits/RESOURCE_QUEUE
			N''SERVER_IDLE_CHECK'', -- https://www.sqlskills.com/help/waits/SERVER_IDLE_CHECK
			N''SLEEP_BPOOL_FLUSH'', -- https://www.sqlskills.com/help/waits/SLEEP_BPOOL_FLUSH
			N''SLEEP_DBSTARTUP'', -- https://www.sqlskills.com/help/waits/SLEEP_DBSTARTUP
			N''SLEEP_DCOMSTARTUP'', -- https://www.sqlskills.com/help/waits/SLEEP_DCOMSTARTUP
			N''SLEEP_MASTERDBREADY'', -- https://www.sqlskills.com/help/waits/SLEEP_MASTERDBREADY
			N''SLEEP_MASTERMDREADY'', -- https://www.sqlskills.com/help/waits/SLEEP_MASTERMDREADY
			N''SLEEP_MASTERUPGRADED'', -- https://www.sqlskills.com/help/waits/SLEEP_MASTERUPGRADED
			N''SLEEP_MSDBSTARTUP'', -- https://www.sqlskills.com/help/waits/SLEEP_MSDBSTARTUP
			N''SLEEP_SYSTEMTASK'', -- https://www.sqlskills.com/help/waits/SLEEP_SYSTEMTASK
			N''SLEEP_TASK'', -- https://www.sqlskills.com/help/waits/SLEEP_TASK
			N''SLEEP_TEMPDBSTARTUP'', -- https://www.sqlskills.com/help/waits/SLEEP_TEMPDBSTARTUP
			N''SNI_HTTP_ACCEPT'', -- https://www.sqlskills.com/help/waits/SNI_HTTP_ACCEPT
			N''SOS_WORK_DISPATCHER'', -- https://www.sqlskills.com/help/waits/SOS_WORK_DISPATCHER
			N''SP_SERVER_DIAGNOSTICS_SLEEP'', -- https://www.sqlskills.com/help/waits/SP_SERVER_DIAGNOSTICS_SLEEP
			N''SQLTRACE_BUFFER_FLUSH'', -- https://www.sqlskills.com/help/waits/SQLTRACE_BUFFER_FLUSH
			N''SQLTRACE_INCREMENTAL_FLUSH_SLEEP'', -- https://www.sqlskills.com/help/waits/SQLTRACE_INCREMENTAL_FLUSH_SLEEP
			N''SQLTRACE_WAIT_ENTRIES'', -- https://www.sqlskills.com/help/waits/SQLTRACE_WAIT_ENTRIES
			N''VDI_CLIENT_OTHER'', -- https://www.sqlskills.com/help/waits/VDI_CLIENT_OTHER
			N''WAIT_FOR_RESULTS'', -- https://www.sqlskills.com/help/waits/WAIT_FOR_RESULTS
			N''WAITFOR'', -- https://www.sqlskills.com/help/waits/WAITFOR
			N''WAITFOR_TASKSHUTDOWN'', -- https://www.sqlskills.com/help/waits/WAITFOR_TASKSHUTDOWN
			N''WAIT_XTP_RECOVERY'', -- https://www.sqlskills.com/help/waits/WAIT_XTP_RECOVERY
			N''WAIT_XTP_HOST_WAIT'', -- https://www.sqlskills.com/help/waits/WAIT_XTP_HOST_WAIT
			N''WAIT_XTP_OFFLINE_CKPT_NEW_LOG'', -- https://www.sqlskills.com/help/waits/WAIT_XTP_OFFLINE_CKPT_NEW_LOG
			N''WAIT_XTP_CKPT_CLOSE'', -- https://www.sqlskills.com/help/waits/WAIT_XTP_CKPT_CLOSE
			N''XE_DISPATCHER_JOIN'', -- https://www.sqlskills.com/help/waits/XE_DISPATCHER_JOIN
			N''XE_DISPATCHER_WAIT'', -- https://www.sqlskills.com/help/waits/XE_DISPATCHER_WAIT
			N''XE_TIMER_EVENT'' -- https://www.sqlskills.com/help/waits/XE_TIMER_EVENT
			)
		AND [waiting_tasks_count] > 0
	)
	INSERT INTO dbo.WaitStats
	 ( [Collection_Time], RowNum, [WaitType] , [Wait_S] , [Resource_S] , [Signal_S] , [WaitCount] , [Percentage] )
	SELECT [Collection_Time] = GETDATE(), RowNum,
			w.wait_type, w.WaitS, w.ResourceS, w.SignalS, w.WaitCount, w.Percentage 
	FROM [Waits] AS w
	ORDER BY [Collection_Time], WaitS DESC, ResourceS DESC, SignalS DESC
	 /*
	SELECT 
		W1.[Collection_Time],
		MAX ([W1].[WaitType]) AS [WaitType],
		CAST (MAX ([W1].[Wait_S]) AS DECIMAL (16,2)) AS [Wait_S],
		CAST (MAX ([W1].[Resource_S]) AS DECIMAL (16,2)) AS [Resource_S],
		CAST (MAX ([W1].[Signal_S]) AS DECIMAL (16,2)) AS [Signal_S],
		MAX ([W1].[WaitCount]) AS [WaitCount],
		CAST (MAX ([W1].[Percentage]) AS DECIMAL (5,2)) AS [Percentage],
		CAST (MAX ([W1].[AvgWait_S]) AS DECIMAL (16,4)) AS [AvgWait_S],
		CAST (MAX ([W1].[AvgRes_S]) AS DECIMAL (16,4)) AS [AvgRes_S],
		CAST (MAX ([W1].[AvgSig_S]) AS DECIMAL (16,4)) AS [AvgSig_S]
		--,MAX([Help/Info URL]) AS [Help/Info URL]
	FROM dbo.WaitStats AS [W1]
	INNER JOIN dbo.WaitStats AS [W2] ON [W2].[RowNum] <= [W1].[RowNum] AND W1.Collection_Time = W2.Collection_Time
	GROUP BY W1.Collection_Time, [W1].[RowNum]
	HAVING SUM ([W2].[Percentage]) - MAX( [W1].[Percentage] ) < 99 -- percentage threshold
	ORDER BY Collection_Time, Percentage desc
	*/
	--select 12/0
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

END CATCH

IF @_errorMessage IS NOT NULL
	THROW 50000, @_errorMessage, 1;', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(dba) Collect Metrics - Wait Stats', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200820, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'edf61f10-a94c-4a92-b2b4-c0baee7043ff'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

/****** Object:  Job [(dba) Collect Metrics - Wait Stats Clearing]    Script Date: 16-Sep-20 4:20:03 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 16-Sep-20 4:20:03 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics - Wait Stats Clearing', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Montly Clear the Wait Stats', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Wait Stats Clearing]    Script Date: 16-Sep-20 4:20:03 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Wait Stats Clearing', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DBCC SQLPERF
(
     "sys.dm_os_wait_stats" , CLEAR 
)   
WITH NO_INFOMSGS ;', 
		@database_name=N'master', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(dba) Collect Metrics - Wait Stats Clearing', 
		@enabled=1, 
		@freq_type=16, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20200820, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'e4a954b8-3b9e-4e2d-931a-18470c1d7f28'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

/****** Object:  Job [(dba) Collect Metrics - WhoIsActive]    Script Date: 16-Sep-20 4:20:04 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 16-Sep-20 4:20:04 PM ******/
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
/****** Object:  Step [Log activities with [sp_WhoIsActive]]    Script Date: 16-Sep-20 4:20:04 PM ******/
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


