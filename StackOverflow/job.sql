USE [msdb]
GO

/****** Object:  Job [Restore StackOverflow2013]    Script Date: 1/30/2024 9:08:46 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 1/30/2024 9:08:46 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
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
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Restore StackOverflow2013]    Script Date: 1/30/2024 9:08:46 PM ******/
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
		@command=N'EXEC sys.sp_configure ''show advanced option'', ''1'';
RECONFIGURE;
		
EXEC sys.sp_configure N''cost threshold for parallelism'', N''50''
EXEC sys.sp_configure N''max degree of parallelism'', N''0''
RECONFIGURE

IF EXISTS(SELECT * FROM sys.databases WHERE name = ''StackOverflow2013'' AND state_desc = ''RECOVERY_PENDING'')
	DROP DATABASE [StackOverflow2013];

IF EXISTS(SELECT * FROM sys.databases WHERE name = ''StackOverflow2013'')
	ALTER DATABASE [StackOverflow2013] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE [StackOverflow2013] 
FROM  DISK = N''E:\Backup\StackOverflow2013.bak'' WITH  FILE = 1,  
MOVE N''StackOverflow2013_1'' TO N''E:\Data\Files\StackOverflow2013_1.mdf'',  
MOVE N''StackOverflow2013_2'' TO N''E:\Data\Files\StackOverflow2013_2.ndf'',  
MOVE N''StackOverflow2013_3'' TO N''E:\Data\Files\StackOverflow2013_3.ndf'',  
MOVE N''StackOverflow2013_4'' TO N''E:\Data\Files\StackOverflow2013_4.ndf'',  
MOVE N''StackOverflow2013_log'' TO N''E:\Log\Files\StackOverflow2013_log.ldf'',  
NOUNLOAD,  STATS = 5, REPLACE;

ALTER DATABASE [StackOverflow2013] SET COMPATIBILITY_LEVEL = 140;

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


