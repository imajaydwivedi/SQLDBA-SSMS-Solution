USE [msdb]
GO

--EXEC msdb.dbo.sp_delete_job @job_name=N'(dba) Run-PlanCacheAutopilot', @delete_unused_schedule=1
GO

DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'(dba) Run-PlanCacheAutopilot', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'Capture Queries having parameter sniffing', 
		@category_name=N'(dba) Monitoring & Alerting', 
		--@owner_login_name=N'sa', 
		@job_id = @jobId OUTPUT
GO
EXEC msdb.dbo.sp_add_jobserver @job_name=N'(dba) Run-PlanCacheAutopilot'
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'(dba) Run-PlanCacheAutopilot', @step_name=N'usp_PlanCacheAutopilot', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'declare @db_name varchar(125);
set @db_name = db_name();

EXEC dbo.usp_PlanCacheAutopilot
	@MinExecutions = 2,
	@MinDurationSeconds = 10,
	@MinCPUSeconds = 10,
	@MinLogicalReads = 100000,
	@MinLogicalWrites = 0,
	@MinSpills = 0,
	@MinGrantMB = 0,
	@OutputDatabaseName = @db_name,
	@OutputSchemaName = ''dbo'',
	@OutputTableName = ''PlanCacheAutopilot'',
	@CheckDateOverride = NULL,
	@LogThePlans = 1,
	@ClearThePlans = 0,
	@Debug = 1;', 
		@database_name=N'DBA', 
		@flags=4
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_name=N'(dba) Run-PlanCacheAutopilot', 
		@enabled=1, 
		@start_step_id=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'Capture Queries having parameter sniffing', 
		@category_name=N'(dba) Monitoring & Alerting', 
		--@owner_login_name=N'sa', 
		@notify_email_operator_name=N'', 
		@notify_page_operator_name=N''
GO
USE [msdb]
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'(dba) Run-PlanCacheAutopilot', @name=N'(dba) Run-PlanCacheAutopilot', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=15, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20220915, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_id = @schedule_id OUTPUT
GO

EXEC msdb.dbo.sp_start_job @job_name=N'(dba) Run-PlanCacheAutopilot'
go

