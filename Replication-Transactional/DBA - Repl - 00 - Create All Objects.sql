USE [DBA]
GO

create partition function pf_dba (datetime2)
as range right for values ('2022-03-25 00:00:00.0000000')
go

create partition scheme ps_dba as partition pf_dba all to ([primary])
go

CREATE TABLE [dbo].[repl_token_header]
(
	[publisher] [varchar](200) NOT NULL,
	[publisher_db] [varchar](200) NOT NULL,
	[publication] [varchar](500) NOT NULL,
	[publication_id] [int] not null,
	[token_id] int NOT NULL,
	[collection_time] [datetime2](7) NOT NULL default sysutcdatetime(),
	[is_processed] bit not null default 0,
	constraint pk_repl_token_header primary key clustered ([publication], [token_id], is_processed, [collection_time]) on ps_dba([collection_time])
) on ps_dba([collection_time])
GO

create index nci_collection_time__filtered on [dbo].[repl_token_header] ([collection_time], [is_processed]) where [is_processed] = 0
go


CREATE TABLE [dbo].[repl_token_insert_log]
(
	[CollectionTimeUTC] [datetime2](7) NULL,
	[Publisher] [varchar](200) NOT NULL,
	[Distributor] [varchar](200) NOT NULL,
	[PublisherDb] [varchar](200) NOT NULL,
	[Publication] [varchar](500) NOT NULL,
	[ErrorMessage] [varchar](4000) NOT NULL,
) on ps_dba([CollectionTimeUTC])
GO

create clustered index ci_replication_tokens_insert_log on [dbo].[repl_token_insert_log]
	([CollectionTimeUTC],[Publisher]) on ps_dba([CollectionTimeUTC])
go


-- drop table [dbo].[repl_token_history]

CREATE TABLE [dbo].[repl_token_history]
(
	[id] bigint identity(1,1) not null,
	[publisher] [sysname] not null,
	[publication_display_name] nvarchar(1000) not null,
	[subscription_display_name] nvarchar(1000) not null,
	[publisher_db] [sysname] not null,
	[publication] [sysname] NOT NULL,
	[publisher_commit] [datetime] NOT NULL,
	[distributor_commit] [datetime] NOT NULL,
	[distributor_latency] int not null, --AS datediff(minute,publisher_commit,distributor_commit),
	[subscriber] [sysname] NOT NULL,
	[subscriber_db] [sysname] NOT NULL,
	[subscriber_commit] [datetime] NOT NULL,
	[subscriber_latency] int not null, -- AS datediff(minute,distributor_commit,subscriber_commit),
	[overall_latency] int not null, --AS datediff(minute,publisher_commit,subscriber_commit),
	[agent_name] nvarchar(2000) not null,
	[collection_time_utc] [datetime2] NOT NULL DEFAULT sysutcdatetime()
	,constraint pk_repl_token_history primary key clustered ([collection_time_utc],id) on ps_dba([collection_time_utc])
) on ps_dba([collection_time_utc])
GO

create nonclustered index nci_repl_token_history on dbo.[repl_token_history]
	(publisher, publication_display_name, subscription_display_name, publisher_commit desc) include (overall_latency) on ps_dba([collection_time_utc])
go







USE [msdb]
GO


BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'(dba) Monitoring & Alerting' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'(dba) Monitoring & Alerting'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Partitions-Maintenance', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'This job takes care of creating new partitions and removing old partitions', 
		@category_name=N'(dba) Monitoring & Alerting', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'Slack_alerting', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Add partitions - Hourly - Till Next Quarter End', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'set nocount on;
declare @current_boundary_value datetime2;
declare @target_boundary_value datetime2; /* last day of new quarter */
set @target_boundary_value = DATEADD (dd, -1, DATEADD(qq, DATEDIFF(qq, 0, GETDATE()) +2, 0));

select top 1 @current_boundary_value = convert(datetime2,prv.value)
from sys.partition_range_values prv
join sys.partition_functions pf on pf.function_id = prv.function_id
where pf.name = ''pf_dba''
order by prv.value desc;

select [@current_boundary_value] = @current_boundary_value, [@target_boundary_value] = @target_boundary_value;

while (@current_boundary_value < @target_boundary_value)
begin
	set @current_boundary_value = DATEADD(hour,1,@current_boundary_value);
	--print @current_boundary_value
	alter partition scheme ps_dba next used [primary];
	alter partition function pf_dba() split range (@current_boundary_value);	
end', 
		@database_name=N'DBA_Inventory', 
		@flags=12
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Remove Partitions - Retain upto 3 Months', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'set nocount on;
declare @partition_boundary datetime2;
declare @target_boundary_value datetime2; /* 3 months back date */
set @target_boundary_value = DATEADD(mm,DATEDIFF(mm,0,GETDATE())-3,0);
--set @target_boundary_value = ''2022-03-25 19:00:00.000''

declare cur_boundaries cursor local fast_forward for
		select convert(datetime2,prv.value) as boundary_value
		from sys.partition_range_values prv
		join sys.partition_functions pf on pf.function_id = prv.function_id
		where pf.name = ''pf_dba'' and convert(datetime2,prv.value) < @target_boundary_value
		order by prv.value asc;

open cur_boundaries;
fetch next from cur_boundaries into @partition_boundary;
while @@FETCH_STATUS = 0
begin
	--print @partition_boundary
	alter partition function pf_dba() merge range (@partition_boundary);

	fetch next from cur_boundaries into @partition_boundary;
end
CLOSE cur_boundaries
DEALLOCATE cur_boundaries;', 
		@database_name=N'DBA_Inventory', 
		@flags=12
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(dba) Partitions-Maintenance - Daily', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=24, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20220326, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'b43ab780-6b08-4127-a36f-e2f478409210'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

