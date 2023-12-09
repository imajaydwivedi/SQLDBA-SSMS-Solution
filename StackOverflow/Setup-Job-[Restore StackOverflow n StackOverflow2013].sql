USE [msdb]
GO

/****** Object:  Job [Restore StackOverflow]    Script Date: 3/1/2023 9:40:15 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 3/1/2023 9:40:15 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Restore StackOverflow', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Restore StackOverflow]    Script Date: 3/1/2023 9:40:15 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Restore StackOverflow', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC sys.sp_configure ''show advanced option'', ''1'';
RECONFIGURE;
		
EXEC sys.sp_configure N''cost threshold for parallelism'', N''50''
EXEC sys.sp_configure N''max degree of parallelism'', N''0''
RECONFIGURE

IF EXISTS(SELECT * FROM sys.databases WHERE name = ''StackOverflow'' AND state_desc = ''RECOVERY_PENDING'')
	DROP DATABASE [StackOverflow];

IF EXISTS(SELECT * FROM sys.databases WHERE name = ''StackOverflow'')
	ALTER DATABASE [StackOverflow] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE [StackOverflow] 
FROM  DISK = N''\\SQLMonitor\Backup\StackOverflow_Training\StackOverflow_1of4.bak'',  
DISK = N''\\SQLMonitor\Backup\StackOverflow_Training\StackOverflow_2of4.bak'',  
DISK = N''\\SQLMonitor\Backup\StackOverflow_Training\StackOverflow_3of4.bak'',  
DISK = N''\\SQLMonitor\Backup\StackOverflow_Training\StackOverflow_4of4.bak'' 
WITH  FILE = 1,  
MOVE N''StackOverflow_1'' TO N''E:\StackOverflow2018\Files\StackOverflow_1.mdf'',  
MOVE N''StackOverflow_2'' TO N''E:\StackOverflow2018\Files\StackOverflow_2.ndf'',  
MOVE N''StackOverflow_3'' TO N''E:\StackOverflow2018\Files\StackOverflow_3.ndf'',  
MOVE N''StackOverflow_4'' TO N''E:\StackOverflow2018\Files\StackOverflow_4.ndf'',  
MOVE N''StackOverflow_log'' TO N''E:\StackOverflow2018\Files\StackOverflow_log.ldf'',  
NOUNLOAD,  REPLACE,  STATS = 5;

ALTER DATABASE [StackOverflow] SET COMPATIBILITY_LEVEL = 140;

', 
		@database_name=N'master', 
		@flags=0
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

/****** Object:  Job [Restore StackOverflow2013]    Script Date: 3/1/2023 9:40:15 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [(dba) SQLMonitor]    Script Date: 3/1/2023 9:40:15 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'(dba) SQLMonitor' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'(dba) SQLMonitor'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Restore StackOverflow2013', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'(dba) SQLMonitor', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Restore StackOverflow2013]    Script Date: 3/1/2023 9:40:15 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Restore StackOverflow2013', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'IF EXISTS(SELECT * FROM sys.databases WHERE name = ''StackOverflow2013'' AND state_desc = ''RECOVERY_PENDING'')
	DROP DATABASE [StackOverflow2013];

IF EXISTS(SELECT * FROM sys.databases WHERE name = ''StackOverflow2013'')
	ALTER DATABASE [StackOverflow2013] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE [StackOverflow2013] 
FROM  DISK = N''\\SQLMonitor\Backup\StackOverflow2013.bak''
WITH	MOVE N''StackOverflow2013_1'' TO N''E:\StackOverflow2013\files\StackOverflow2013_1.mdf'',  
		MOVE N''StackOverflow2013_2'' TO N''E:\StackOverflow2013\files\StackOverflow2013_2.mdf'',  
		MOVE N''StackOverflow2013_3'' TO N''E:\StackOverflow2013\files\StackOverflow2013_3.mdf'',  
		MOVE N''StackOverflow2013_4'' TO N''E:\StackOverflow2013\files\StackOverflow2013_4.mdf'',  
		MOVE N''StackOverflow2013_log'' TO N''E:\StackOverflow2013\Files\StackOverflow2013_log.ldf'',  
NOUNLOAD,  REPLACE,  STATS = 5;

ALTER DATABASE [StackOverflow2013] SET COMPATIBILITY_LEVEL = 140;
', 
		@database_name=N'master', 
		@flags=12
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


