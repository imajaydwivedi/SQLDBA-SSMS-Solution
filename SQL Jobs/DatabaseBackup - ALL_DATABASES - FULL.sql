USE [msdb]
GO

/****** Object:  Job [DatabaseBackup - ALL_DATABASES - FULL]    Script Date: 1/25/2020 2:25:02 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 1/25/2020 2:25:02 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DatabaseBackup - ALL_DATABASES - FULL', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Source: https://ola.hallengren.com

This jobs calls following jobs:-

[DatabaseBackup - ALL_DATABASES - FULL - 01/03]
[DatabaseBackup - ALL_DATABASES - FULL - 02/03]
[DatabaseBackup - ALL_DATABASES - FULL - 03/03]
', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'DBAGroup', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Create Base table [tempdb]..[DatabaseBackup_Size_info]]    Script Date: 1/25/2020 2:25:02 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Create Base table [tempdb]..[DatabaseBackup_Size_info]', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'IF OBJECT_ID(''tempdb..DatabaseBackup_Size_info'') IS NOT NULL
	DROP TABLE tempdb..DatabaseBackup_Size_info;

select mf.database_id, db_name(mf.database_id) as dbName, sum((mf.size/8.0)/1024) as size
		,ROW_NUMBER()OVER(ORDER BY sum((mf.size/8.0)/1024) desc) as SizeRank
INTO tempdb..DatabaseBackup_Size_info
from sys.master_files mf
where mf.type_desc = ''ROWS''
AND db_name(mf.database_id) NOT IN (''tempdb'') -- Exception databases
AND mf.physical_name not like ''C:\AppSyncMounts\%''
AND mf.database_id not in (select d.database_id from sys.databases as d where d.is_in_standby = 1)
group by mf.database_id;', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Start child Jobs]    Script Date: 1/25/2020 2:25:02 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Start child Jobs', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec msdb..sp_start_job @job_name = ''DatabaseBackup - ALL_DATABASES - FULL - 01'';

exec msdb..sp_start_job @job_name = ''DatabaseBackup - ALL_DATABASES - FULL - 02'';

exec msdb..sp_start_job @job_name = ''DatabaseBackup - ALL_DATABASES - FULL - 03'';

', 
		@database_name=N'master', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Nightly', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20191021, 
		@active_end_date=99991231, 
		@active_start_time=190000, 
		@active_end_time=235959, 
		@schedule_uid=N'd6e037cb-f4b5-416a-8beb-f641abe0b296'
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

/****** Object:  Job [DatabaseBackup - ALL_DATABASES - FULL - 01]    Script Date: 1/25/2020 2:25:09 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 1/25/2020 2:25:09 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DatabaseBackup - ALL_DATABASES - FULL - 01', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Source: https://ola.hallengren.com

This job is started from job [DatabaseBackup - ALL_DATABASES - FULL]', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'DBAGroup', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [DatabaseBackup - ALL_DATABASES - FULL - 01]    Script Date: 1/25/2020 2:25:09 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseBackup - ALL_DATABASES - FULL - 01', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @Parallel_Job_Counts SMALLINT = 3; -- Total count of parallel jobs
DECLARE @Parallel_Job_Id INT = 01; -- Parallel job Number

DECLARE @_dbNames VARCHAR(MAX);

/* Get Comma Separated List of  Database Names which are not on APPSYNC */
SELECT	@_dbNames = COALESCE(@_dbNames+'',''+dbName,dbName)
FROM	[tempdb]..[DatabaseBackup_Size_info]
WHERE	((SizeRank%@Parallel_Job_Counts)+1) = @Parallel_Job_Id
order by size desc;
	
select @_dbNames;

EXECUTE [DBA].[dbo].[DatabaseBackup] 
		@Databases = @_dbNames
		,@Directory = N''J:\MSSQL15.MSSQLSERVER\Backups''
		,@FileName = N''{DatabaseName}_{BackupType}_{Partial}_{CopyOnly}_{Year}{Month}{Day}.{FileExtension}''
		,@DirectoryStructure = NULL
		,@BackupType = ''FULL''
		,@Verify = ''N''
		,@INIT = ''Y''
		,@Compress = ''Y''
		,@CleanupTime = 20
		,@CleanupMode = ''BEFORE_BACKUP''
		,@CheckSum = ''N''
		,@LogToTable = ''Y''
		,@Execute = ''Y''
', 
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


