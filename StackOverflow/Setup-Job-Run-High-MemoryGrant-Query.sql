USE [msdb]
GO

/****** Object:  Job [Run-High-MemoryGrant-Query]    Script Date: 12/12/2022 6:54:56 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 12/12/2022 6:54:56 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Run-High-MemoryGrant-Query', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'select p.Tags, Location, count(*) as total_posts, 
		sum(CommentCount) as CommentCount, 
		FavoriteCount = sum(FavoriteCount),
		Score = sum(Score),
		PostTypes = count(distinct p.PostTypeId),
		UpVotes = sum(u.UpVotes)
from dbo.Posts p join dbo.Users u on u.Id = p.OwnerUserId
where P.OwnerUserId % 3 <= 3 and (ltrim(rtrim(p.Tags)) like ''%s%'' or ltrim(rtrim(p.Tags)) not like ''%s%'')
group by p.Tags, Location
order by Location, Tags, Score desc, 
		(case when u.Location like ''%a%'' then 1 
				when u', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Run-High-MemoryGrant-Query]    Script Date: 12/12/2022 6:54:57 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Run-High-MemoryGrant-Query', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'select p.Tags, Location, count(*) as total_posts, 
		sum(CommentCount) as CommentCount, 
		FavoriteCount = sum(FavoriteCount),
		Score = sum(Score),
		PostTypes = count(distinct p.PostTypeId),
		UpVotes = sum(u.UpVotes)
from dbo.Posts p join dbo.Users u on u.Id = p.OwnerUserId
where P.OwnerUserId % 3 <= 3 and (ltrim(rtrim(p.Tags)) like ''%s%'' or ltrim(rtrim(p.Tags)) not like ''%s%'')
group by p.Tags, Location
order by Location, Tags, Score desc, 
		(case when u.Location like ''%a%'' then 1 
				when u.Location like ''%e%'' then 2
				when u.Location like ''%i%'' then 2
				when u.Location like ''%o%'' then 2
				when u.Location like ''%u%'' then 2
				else 10 end)', 
		@database_name=N'StackOverflow', 
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


