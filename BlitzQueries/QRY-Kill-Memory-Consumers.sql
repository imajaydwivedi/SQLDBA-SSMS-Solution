/*
declare @start_time datetime2 = sysdatetime();
declare @my_login varchar(100) = ORIGINAL_LOGIN();
declare @login_not_in varchar(100) = 'Lab\SQLServices';
declare @kill_string nvarchar(200);
declare @memory_threshold_mb int = 1000;
declare @include_open_tran bit = 1;
declare @only_blocked_sessions bit = 0;

declare @sql nvarchar(max);
declare @params nvarchar(2000);
set @params = N'@memory_threshold_mb int, @include_open_tran bit, @my_login varchar(100), @login_not_in varchar(100)';

set quoted_identifier off;
set @sql = "
select [memory_gb] = convert(numeric(20,2),der.granted_query_memory*8.0/1024/1024), 
		[--kill query--] = 'kill '+convert(varchar,der.session_id)+char(10)
		,[--find-query--] = 'dbcc inputbuffer('+convert(varchar,der.session_id)+')'
		,[tran count(ssn+req)] = cast(des.open_transaction_count as varchar)+ '+' + convert(varchar,der.open_transaction_count)
		,[elapsed_time] = convert(varchar,getdate()-der.start_time,108)
		,der.session_id, der.status, der.command
		,[db_name] = db_name(der.database_id), des.login_name, des.program_name, des.host_name
		,der.blocking_session_id, der.wait_type, 
		[wait_time] = convert(varchar,dateadd(ms,wait_time,'1900-01-01 00:00:00.000'),108)
		,der.wait_resource, der.percent_complete, der.cpu_time, der.total_elapsed_time
		,der.logical_reads, der.writes, der.row_count, query_hash /* , dop, parallel_worker_count */
from sys.dm_exec_requests der join sys.dm_exec_sessions des
	on des.session_id = der.session_id
where der.granted_query_memory >= (@memory_threshold_mb*1024/8)
"+(case when @include_open_tran = 1 then '-- ' else '' end)+"and (der.open_transaction_count = 0 and des.open_transaction_count = 0)
"+(case when @my_login is null then '-- ' else '' end)+"and des.login_name <> @my_login
"+(case when @login_not_in is null then '-- ' else '' end)+"and des.login_name <> @login_not_in
"+(case when @only_blocked_sessions = 0 then '-- ' else '' end)+"and der.blocking_session_id > 0 
order by granted_query_memory desc;	
"
set quoted_identifier on;

exec sp_executesql @sql, @params, @memory_threshold_mb, @include_open_tran, @my_login, @login_not_in;
*/
go
-- Parameters
declare @include_open_tran bit = 0,
		@skip_my_login bit = 0,
		@debug bit = 1,
		@memory_threshold_mb int = 500;
-- Variables
declare @start_time datetime2 = sysdatetime(),
		@my_login varchar(100) = ORIGINAL_LOGIN(),
		@kill_string nvarchar(200),
		@session_id int,
		@memory_grant_mb int;

--while (dateadd(MINUTE,30,@start_time) >= SYSDATETIME())
while (dateadd(MINUTE,10,@start_time) >= SYSDATETIME() and (select cntr_value from sys.dm_os_performance_counters pc where pc.counter_name like 'Memory Grants Pending%') > 0 )
begin
	declare cur_connections cursor static local for 
					select [--kill query--] = 'kill '+convert(varchar,der.session_id), der.session_id,
							[memory_grant_mb] = der.granted_query_memory*8/1024
					from sys.dm_exec_requests der join sys.dm_exec_sessions des
						on des.session_id = der.session_id
					where der.granted_query_memory >= (@memory_threshold_mb*1024/8)
					and (	@include_open_tran = 1 
						or (der.open_transaction_count = 0 and des.open_transaction_count = 0) 
						)
					and (@skip_my_login = 0 or (@skip_my_login = 1 and des.login_name <> @my_login))
					order by granted_query_memory desc;

	open cur_connections;
	fetch next from cur_connections into @kill_string, @session_id, @memory_grant_mb;

	while @@FETCH_STATUS = 0
	begin
		begin try
			if @debug = 0
			begin
				print @kill_string
				exec (@kill_string);
			end
			else
			begin
				select	[@session_id] = @session_id, 
						[@memory_grant_mb] = case when @memory_grant_mb >= 1024 then convert(varchar,convert(numeric(20,1),@memory_grant_mb*1.0/1024))+' gb'
													else convert(varchar,@memory_grant_mb)+' mb'
													end
				exec sp_WhoIsActive @filter = @session_id, @get_outer_command = 1, @get_plans = 1;
			end
		end try
		begin catch
		end catch
		fetch next from cur_connections into @kill_string, @session_id, @memory_grant_mb;
	end

	close cur_connections
	deallocate cur_connections

	if @debug = 1
		waitfor delay '00:01:00'
	else
		waitfor delay '00:00:02'
end;