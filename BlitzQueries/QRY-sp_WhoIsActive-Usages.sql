EXEC sp_WhoIsActive @get_outer_command = 1, @get_task_info=2, @get_additional_info=1, @get_memory_info = 1 --,@get_avg_time=1,
					,@find_block_leaders=1
					,@get_transaction_info=1
					--,@show_system_spids=1
					--,@get_full_inner_text=1
					--,@get_locks=1
					,@get_plans=1
					--,@sort_order = '[CPU] DESC'
					--,@filter = 94
					--,@filter_type = 'login' ,@filter = 'grafana'
					--,@filter_type = 'program' ,@filter = 'sqlcmd'
					--,@filter_type = 'database' ,@filter = 'tempdb'
					--,@filter_type = 'host', @filter = 'SqlPractice'
					--,@sort_order = '[tran_log_writes], [start_time]'
					--,@sort_order = '[tempdb_allocations] desc, [tempdb_current] desc'
					--,@sort_order = '[used_memory] desc, [start_time]'
					--,@sort_order = '[blocked_session_count] desc, [granted_memory] desc, [start_time]'
					,@output_column_list = '[dd hh:mm:ss.mss][session_id][sql_text][query_plan][sql_command][login_name][wait_info][status][blocked_session_count][blocking_session_id][tasks][CPU][reads][used_memory][granted_memory][host_name][database_name][program_name][open_tran_count][start_time][%]'

-- kill 104

/*	Enable LIVE Query Plans
DBCC TRACESTATUS(7412);
DBCC TRACEON(7412, -1);
DBCC TRACEOFF(7412, -1);

exec sp_BlitzWho @GetLiveQueryPlan=1

--Get the execution plan and current progress for session 159
select * from sys.dm_exec_query_statistics_xml(159);
*/

--kill 74 with statusonly
--EXEC sp_WhoIsActive @get_outer_command = 1, @get_task_info=2, @get_locks=1

-- EXEC sp_WhoIsActive  @delta_interval = 5
					
/*
EXEC sp_WhoIsActive @filter_type = 'login' ,@filter = 'lab\adwivedi'
					,@output_column_list = '[session_id][percent_complete][sql_text][login_name][wait_info][blocking_session_id][start_time]'

EXEC sp_WhoIsActive @filter_type = 'session' ,@filter = '174'
					,@output_column_list = '[session_id][percent_complete][sql_text][login_name][wait_info][blocking_session_id][start_time]'

--	EXEC sp_WhoIsActive @destination_table = 'DBA.dbo.WhoIsActive_ResultSets'

*/

--	exec sp_WhoIsActive @help = 1

