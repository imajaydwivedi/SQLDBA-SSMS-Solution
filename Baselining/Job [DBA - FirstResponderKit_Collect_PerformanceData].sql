USE [msdb]
GO

/****** Object:  Job [DBA - FirstResponderKit_Collect_PerformanceData]    Script Date: 2/20/2019 1:18:38 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [DBA]    Script Date: 2/20/2019 1:18:38 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'DBA' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'DBA'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA - FirstResponderKit_Collect_PerformanceData', 
		@enabled=1, 
		@notify_level_eventlog=2, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Job Name:	FirstResponderKit_Collect_PerformanceData
Created By:	Ajay Dwivedi
Purpose:	This job will collect data regarding running sessions, waits stats and queries.
		Data is being collect for 14 days in DBA database tables like dbo.Blitz*****.', 
		@category_name=N'DBA', 
		@owner_login_name=N'Contso\adwivedi', 
		@notify_email_operator_name=N'Ajay Dwivedi', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [FirstResponderKit_Collect_PerformanceData]    Script Date: 2/20/2019 1:18:38 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'FirstResponderKit_Collect_PerformanceData', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC DBA..sp_BlitzFirst 
  @OutputDatabaseName = ''DBA'', 
  @OutputSchemaName = ''dbo'', 
  @OutputTableName = ''BlitzFirst'',
  @OutputTableNameFileStats = ''BlitzFirst_FileStats'',
  @OutputTableNamePerfmonStats = ''BlitzFirst_PerfmonStats'',
  @OutputTableNameWaitStats = ''BlitzFirst_WaitStats'',
  @OutputTableNameBlitzCache = ''BlitzCache'',
  @OutputTableRetentionDays = 3;', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Start [DBA - Log_With_sp_WhoIsActive] Job]    Script Date: 2/20/2019 1:18:38 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Start [DBA - Log_With_sp_WhoIsActive] Job', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC msdb..sp_start_job N''DBA - Log_With_sp_WhoIsActive'' ; ', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily_Every_5_Minutes', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20180315, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235900, 
		@schedule_uid=N'deebbf80-9cc2-47cb-830b-5205b152c5c4'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


