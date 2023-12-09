USE [msdb]
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics - Pool CPU', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Ajay-

I find inconsistency in CPU alert since schedulers are shared by Pools.

So Creating this job for evidencing

select top 100 * 
from DBA.dbo.resource_pool_cpu rp
where rp.[Current-Time-UTC] >= dateadd(minute,-15,GETDATE())


select top 100 * 
from DBA.dbo.resource_pool_program rp
where rp.[Current-Time-UTC] >= dateadd(minute,-15,GETDATE())
', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [(dba) Collect Metrics - Pool CPU]    Script Date: 12/15/2021 8:09:32 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'(dba) Collect Metrics - Pool CPU', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Begin Code to find Resource Pool Scheduler Affinity */
set nocount on;

declare @current_time_utc datetime;
set @current_time_utc = convert(datetime,sysutcdatetime());

if OBJECT_ID(''tempdb..#resource_pool'') is not null	drop table #resource_pool;
if OBJECT_ID(''tempdb..#temp'') is not null	drop table #temp;

create table #resource_pool (rpoolname sysname, scheduler_id int, cpu_id int);
create table #temp (name sysname, pool_id int, scheduler_mask bigint);

insert into #temp
select rp.name,rp.pool_id,pa.scheduler_mask 
from sys.dm_resource_governor_resource_pools rp 
left join sys.resource_governor_resource_pool_affinity pa on rp.pool_id=pa.pool_id
where rp.pool_id>2;

--select * from #temp

if not exists (select * from #temp where scheduler_mask is not null)
	print ''WARNING: No Scheduler Affinity Defined'';
else
begin
	while((select count(1) from #temp) > 0)
	Begin
	declare @intvalue numeric,@rpoolname sysname
	declare @vsresult varchar(64)
	declare @inti numeric
	DECLARE @counter int=0
	select @inti = 64, @vsresult = ''''
	select top 1 @intvalue = scheduler_mask,@rpoolname = name from #temp
	while @inti>0
	  begin
	  if(@intvalue %2 =1)
	  BEGIN
		insert into #resource_pool(rpoolname,scheduler_id) values(@rpoolname,@counter)
	  END
		select @intvalue = convert(bigint, (@intvalue / 2)), @inti=@inti-1
		set @counter = @counter+1
	  end
	  delete from #temp where name= @rpoolname
	End

	update rpl
	set rpl.cpu_id = dos.cpu_id
	from sys.dm_os_schedulers dos inner join #resource_pool rpl
	on dos.scheduler_id=rpl.scheduler_id
end

-- Insert schedulers NOT assigned to Any Pool, and still utilized by SQL Server
insert into #resource_pool
select ''General'' as rpoolname, dos.scheduler_id,dos.cpu_id 
from sys.dm_os_schedulers dos
left join #resource_pool rpl on dos.scheduler_id = rpl.scheduler_id 
where rpl.scheduler_id is NULL and dos.status = ''VISIBLE ONLINE'';
--select * from #resource_pool

/* End Code to find Resource Pool Scheduler Affinity */


declare @object_name varchar(255);
set @object_name = (case when @@SERVICENAME = ''MSSQLSERVER'' then ''SQLServer'' else ''MSSQL$''+@@SERVICENAME end);
;WITH T_Pools AS (
	SELECT /* counter that require Fraction & Base */
			''Resource Pool CPU %'' as RunningQuery,
			rtrim(fr.instance_name) as [Pool], 
			[% CPU @Server-Level] = case when bs.cntr_value <> 0 then (100.0*((fr.cntr_value*1.0)/(bs.cntr_value*1.0))) else fr.cntr_value*1.0 end,
			[% CPU @SqlInstance-Level] = case when bs.cntr_value <> 0 then (100.0*((fr.cntr_value*1.0)/(bs.cntr_value*1.0*((1.0*dos.cpu_sql_counts)/(dos.cpu_total_counts*1.0))))) else fr.cntr_value*1.0 end,
			[% Schedulers@Total] = case when rp.Scheduler_Count <> 0 then (((rp.Scheduler_Count*1.0)/dos.cpu_total_counts)*100.0) else NULL end,	
			[% Schedulers@Sql] = case when rp.Scheduler_Count <> 0 then (((rp.Scheduler_Count*1.0)/dos.cpu_sql_counts)*100.0) else NULL end,	
			[Assigned Schedulers] = case when rp.Scheduler_Count <> 0 then rp.Scheduler_Count else null end
			,dos.cpu_sql_counts ,dos.cpu_total_counts
	FROM sys.dm_os_performance_counters as fr
	JOIN (select count(1)*1.0 as cpu_total_counts, sum(case when dos.status = ''VISIBLE ONLINE'' then 1 else 0 end) as cpu_sql_counts
			from sys.dm_os_schedulers as dos where dos.status IN (''VISIBLE ONLINE'',''VISIBLE OFFLINE'')
		) AS dos ON 1 = 1
	OUTER APPLY
		(	SELECT * FROM sys.dm_os_performance_counters as bs 
			WHERE bs.cntr_type = 1073939712 /* PERF_LARGE_RAW_BASE  */ 
			AND bs.[object_name] = fr.[object_name] 
			AND (	REPLACE(LOWER(RTRIM(bs.counter_name)),'' base'','''') = REPLACE(LOWER(RTRIM(fr.counter_name)),'' ratio'','''')
				OR
				REPLACE(LOWER(RTRIM(bs.counter_name)),'' base'','''') = LOWER(RTRIM(fr.counter_name))
				)
			AND bs.instance_name = fr.instance_name
		) as bs
	OUTER APPLY (	SELECT COUNT(*) as Scheduler_Count FROM #resource_pool AS rp WHERE rp.rpoolname = rtrim(fr.instance_name)	) as rp
	WHERE fr.cntr_type = 537003264 /* PERF_LARGE_RAW_FRACTION */
		--and fr.cntr_value > 0.0
		and
		(
			( fr.[object_name] like (@object_name+'':Resource Pool Stats%'') and fr.counter_name like ''CPU usage %'' )
		)
)

INSERT DBA.dbo.resource_pool_cpu
SELECT @current_time_utc as [Current-Time-UTC], [Pool], 
		[% CPU @Pool-Level] = CONVERT(NUMERIC(20,2),
							CASE	WHEN [Assigned Schedulers] IS NULL THEN NULL 
									WHEN [% Schedulers@Sql] <> 0 THEN (([% CPU @SqlInstance-Level]*100.0)/([% Schedulers@Sql]*1.0)) 
									ELSE [% CPU @SqlInstance-Level] END
							),
		convert(numeric(20,2),[% CPU @SqlInstance-Level]) AS [% CPU @SqlInstance-Level],
		[Assigned Schedulers], p.cpu_sql_counts as [Sql Schedulers], p.cpu_total_counts as [Total Schedulers]
--INTO DBA.dbo.resource_pool_cpu
FROM T_Pools as p
WHERE NOT ([Assigned Schedulers] IS NULL AND [% CPU @Server-Level] = 0)

--SELECT scheduler_id,count(*) FROM #resource_pool AS rp group by scheduler_id

DECLARE @pool_name sysname --= ''FB'';
IF (SELECT count(distinct rpoolname) FROM #resource_pool) < 2
	SET @pool_name = NULL;
;WITH T_Requests AS 
(
	SELECT [Pool], s.program_name, r.session_id, r.request_id
	FROM  sys.dm_exec_requests r
	JOIN	sys.dm_exec_sessions s ON s.session_id = r.session_id
	OUTER APPLY
		(	select rgrp.name as [Pool]
			from sys.resource_governor_workload_groups rgwg 
			join sys.resource_governor_resource_pools rgrp ON rgwg.pool_id = rgrp.pool_id
			where rgwg.group_id = s.group_id
		) rp
	WHERE s.is_user_process = 1	
		AND login_name NOT LIKE ''%sqlservices%''
		AND (@pool_name is null or [Pool] = @pool_name )
)
,T_Programs_Tasks_Total AS
(
	SELECT	[Pool], r.program_name,
			[active_request_counts] = COUNT(*),
			[num_tasks] = SUM(t.tasks)
	FROM  T_Requests as r
	OUTER APPLY (	select count(*) AS tasks, count(distinct t.scheduler_id) as schedulers 
								from sys.dm_os_tasks t where r.session_id = t.session_id and r.request_id = t.request_id
							) t
	GROUP  BY [Pool], r.program_name
)
,T_Programs_Schedulers AS
(
	SELECT [Pool], r.program_name, [num_schedulers] = COUNT(distinct t.scheduler_id)
	FROM T_Requests as r
	JOIN sys.dm_os_tasks t
		ON t.session_id = r.session_id AND t.request_id = r.request_id
	GROUP BY [Pool], program_name
)

INSERT DBA.dbo.resource_pool_program
SELECT @current_time_utc as [Current-Time-UTC], 
		ptt.[Pool],
		ptt.program_name, ptt.active_request_counts, ptt.num_tasks, ps.num_schedulers, 
		[scheduler_percent] = case when @pool_name is not null then Floor(ps.num_schedulers * 100.0 / rp.Scheduler_Count)
									else Floor(ps.num_schedulers * 100.0 / (select count(*) from sys.dm_os_schedulers as os where os.status = ''VISIBLE ONLINE''))
									end
--INTO DBA.dbo.resource_pool_program
FROM	T_Programs_Tasks_Total as ptt
JOIN	T_Programs_Schedulers as ps
	ON ps.Pool = ptt.Pool AND ps.program_name = ptt.program_name
OUTER APPLY (	SELECT COUNT(*) as Scheduler_Count FROM #resource_pool AS rp WHERE rp.rpoolname = ptt.[Pool]	) as rp
ORDER  BY [Pool], [scheduler_percent] desc, active_request_counts desc, [num_tasks] desc;

--drop table DBA.dbo.resource_pool_program', 
		@database_name=N'master', 
		@flags=12
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(dba) Collect Metrics - Pool CPU', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=2, 
		@freq_subday_interval=10, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20201218, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'ad9a7f4a-a0fd-4329-828d-b55f6bb13675'
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

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'(dba) Enable Always' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'(dba) Enable Always'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Collect Metrics - Purge Data', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'
--select * from DBA.dbo.resource_pool_cpu
--select * from DBA.dbo.resource_pool_program', 
		@category_name=N'(dba) Enable Always', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [DBA..resource_pool_cpu]    Script Date: 12/15/2021 8:10:33 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DBA..resource_pool_cpu', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @r INT;
	
SET @r = 1;
while @r > 0
begin
	delete top (100000) rpc
	from dbo.resource_pool_cpu rpc
	where rpc.[Current-Time-UTC] < dateadd(day,-90,sysutcdatetime())
	--option (table hint(h, INDEX(ci_alwayson_synchronization_history_aggregated)))

	set @r = @@ROWCOUNT
end', 
		@database_name=N'DBA', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [DBA..resource_pool_program]    Script Date: 12/15/2021 8:10:41 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DBA..resource_pool_program', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @r INT;
	
SET @r = 1;
while @r > 0
begin
	delete top (100000) rpp
	from dbo.resource_pool_program rpp
	where rpp.[Current-Time-UTC] < dateadd(day,-90,sysutcdatetime())
	--option (table hint(h, INDEX(ci_alwayson_synchronization_history_aggregated)))

	set @r = @@ROWCOUNT
end', 
		@database_name=N'DBA', 
		@flags=12
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Add partition for tomorrow]    Script Date: 12/15/2021 8:10:46 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Add partition for tomorrow', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'set nocount on;
set datefirst 1;
declare @weeks_retention int = 26;
declare @today datetime = convert(datetime,convert(date,getdate()));
declare @tomorrow datetime = @today+1;
declare @day_after_tomorrow datetime = @today+2;
declare @yesterday datetime = @today-1;
declare @day_before_yesterday datetime = @today-2;
declare @week_start datetime = dateadd(day,-datepart(weekday,@today)+1,@today);

-- Add tomorrow & day_after_tomorrow
if not exists (select * from sys.partition_range_values where value = @day_after_tomorrow)
begin
	if not exists (select * from sys.partition_range_values where value = @tomorrow)
	begin
		ALTER PARTITION SCHEME sch_partition_resource_pool_cpu NEXT USED [PRIMARY];
		ALTER PARTITION FUNCTION fn_partition_resource_pool_cpu () SPLIT RANGE (@tomorrow);
	end
	ALTER PARTITION SCHEME sch_partition_resource_pool_cpu NEXT USED [PRIMARY];
	ALTER PARTITION FUNCTION fn_partition_resource_pool_cpu () SPLIT RANGE (@day_after_tomorrow);
end', 
		@database_name=N'DBA', 
		@flags=12
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Remove unused partitions]    Script Date: 12/15/2021 8:10:51 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Remove unused partitions', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'set nocount on;
set datefirst 1;
declare @retention_days int = 90;
declare @date_90_days datetime = dateadd(day,-@retention_days,convert(datetime,convert(date,getdate())));
declare @week_start_90_days datetime = dateadd(day,-datepart(weekday,@date_90_days)+1,@date_90_days);
declare @partition_scheme_name sysname = ''sch_partition_resource_pool_cpu'';
declare @partition_function_name sysname = ''fn_partition_resource_pool_cpu'';
declare @table_name sysname = ''dbo.resource_pool_cpu'';
declare @partitions_to_truncate_start varchar(10);
declare @partitions_to_truncate_end varchar(10);
declare @partition_boundary varchar(20);
declare @sql nvarchar(max);

if OBJECT_ID(''tempdb..#purge_partitions'') is not null
	drop table #purge_partitions;
select object_name(p.object_id) as table_name, s.name as partition_scheme_name, p.partition_number, 
		f.name as partition_function_name,
		lv.value leftValue, rv.value rightValue, 
		p.rows AS NumberOfRows
into #purge_partitions
from sys.partitions p
join sys.allocation_units a
on p.hobt_id = a.container_id
join sys.indexes i
on p.object_id = i.object_id
join sys.partition_schemes s
on i.data_space_id = s.data_space_id
join sys.partition_functions f
on s.function_id = f.function_id
left join sys.partition_range_values rv
on f.function_id = rv.function_id
and p.partition_number = rv.boundary_id
left join sys.partition_range_values lv
on f.function_id = lv.function_id
and p.partition_number - 1 = lv.boundary_id
where p.object_id = object_id(@table_name)
and rv.value < @week_start_90_days
order by partition_number;

-- select * from #purge_partitions;
select @partitions_to_truncate_start = min(partition_number), @partitions_to_truncate_end = max(partition_number) 
from #purge_partitions;

-- Purge Partitions 
set @sql = ''TRUNCATE TABLE ''+@table_name+'' WITH (PARTITIONS (''+@partitions_to_truncate_start+'' TO ''+@partitions_to_truncate_end+''));'';
--exec (@sql);
/* Only supported from SQL 2016 */
print @sql+CHAR(10)

-- Merge Previous Week Partitions
declare cur_partitions cursor local forward_only for 
	select convert(date,rightValue,112) from #purge_partitions;
open cur_partitions;
fetch next from cur_partitions into @partition_boundary;
while @@FETCH_STATUS = 0
begin
	set @sql = ''ALTER PARTITION FUNCTION ''+@partition_function_name+'' ()  MERGE RANGE (''''''+@partition_boundary+'''''');''
	print @sql
	exec (@sql)
	fetch next from cur_partitions into @partition_boundary;
end
CLOSE cur_partitions
DEALLOCATE cur_partitions;', 
		@database_name=N'DBA', 
		@flags=12
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Merge Previous Week Partitions]    Script Date: 12/15/2021 8:10:51 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Merge Previous Week Partitions', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
set nocount on;
set datefirst 1;
declare @today datetime = convert(datetime,convert(date,getdate()));
declare @week_start datetime = dateadd(day,-datepart(weekday,@today)+1,@today);
declare @week_previous datetime = dateadd(week,-1,@week_start)
declare @partition_scheme_name sysname = ''sch_partition_resource_pool_cpu'';
declare @partition_function_name sysname = ''fn_partition_resource_pool_cpu'';
declare @table_name sysname = ''dbo.resource_pool_cpu'';
declare @partition_boundary varchar(20);
declare @sql nvarchar(max);

-- select @week_start,@today,@week_previous

if OBJECT_ID(''tempdb..#purge_partitions'') is not null
	drop table #purge_partitions;
select object_name(p.object_id) as table_name, s.name as partition_scheme_name, p.partition_number, 
		f.name as partition_function_name,
		lv.value leftValue, rv.value rightValue, 
		p.rows AS NumberOfRows
into #purge_partitions
from sys.partitions p
join sys.allocation_units a
on p.hobt_id = a.container_id
join sys.indexes i
on p.object_id = i.object_id
join sys.partition_schemes s
on i.data_space_id = s.data_space_id
join sys.partition_functions f
on s.function_id = f.function_id
left join sys.partition_range_values rv
on f.function_id = rv.function_id
and p.partition_number = rv.boundary_id
left join sys.partition_range_values lv
on f.function_id = lv.function_id
and p.partition_number - 1 = lv.boundary_id
where p.object_id = object_id(@table_name)
and (rv.value  > @week_previous and rv.value < @week_start)
order by partition_number;

-- select * from #purge_partitions order by partition_number

-- Merge Previous Week Partitions
if exists (select * from #purge_partitions)
begin
	declare cur_partitions cursor local fast_forward for 
		select convert(date,rightValue,112) from #purge_partitions order by partition_number;
	open cur_partitions;
	fetch next from cur_partitions into @partition_boundary;
	while @@FETCH_STATUS = 0
	begin
		set @sql = ''ALTER PARTITION FUNCTION ''+@partition_function_name+'' ()  MERGE RANGE (''''''+@partition_boundary+'''''');''
		print @sql
		exec (@sql)
		fetch next from cur_partitions into @partition_boundary;
	end
	CLOSE cur_partitions
	DEALLOCATE cur_partitions;
end', 
		@database_name=N'DBA', 
		@flags=12
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(dba) Collect Metrics - Purge Data', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=4, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20210311, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'7847194e-806c-49d4-ad58-6f54e3e2a8a5'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


/* Grafana Queries */

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
DECLARE @From datetime = '2021-12-31T04:08:19Z';
DECLARE @To datetime = '2021-12-31T04:38:19Z';
DECLARE @Server sysname = 'MyProdServer';
DECLARE @sql varchar(max) 

SET QUOTED_IDENTIFIER OFF 

SET @sql = "
if object_id ('DBA.dbo.resource_pool_cpu') is not null
begin
	select rpc.[Current-Time-UTC] as [time], [% CPU @Pool-Level] = COALESCE(rpc.[% CPU @Pool-Level], rpc.[% CPU @SqlInstance-Level]),
	      Pool = Pool + ' ('+CAST(COALESCE([Assigned Schedulers],[Sql Schedulers]) AS varchar)+')'
	from DBA.dbo.resource_pool_cpu rpc
	where rpc.[Current-Time-UTC] >= '"+convert(varchar,@From,120)+"'
       AND rpc.[Current-Time-UTC] <= '"+convert(varchar,@To,120)+"'
         AND (rpc.[% CPU @Pool-Level] > 0.0 OR rpc.[% CPU @SqlInstance-Level] > 0.0)
  order by [time] ASC, [% CPU @Pool-Level] DESC
end
"
SET QUOTED_IDENTIFIER ON
IF ('MyProdServer' = SERVERPROPERTY('ServerName'))
BEGIN
	EXEC (@sql)
END;
ELSE
BEGIN
	EXEC (@sql) AT MyProdServer;
END;