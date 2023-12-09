use DBA
;with t_captures as
(	select DENSE_RANK()over(order by try_cast(r.sql_command as varchar(max))) as QueryID,
			ROW_NUMBER()over(partition by try_cast(r.sql_command as varchar(max)) order by r.timeInMinutes desc) as TimeDurationOrderID,
			* 
	from DBA..whoisactive_resultsets r 
	where r.program_name <> 'Microsoft® Windows® Operating System'
)
select top 10 [collection_time], [TimeInMinutes], [dd hh:mm:ss.mss], [session_id], [sql_text], [sql_command], [login_name], 
		[wait_info], [tasks], [tran_log_writes], [CPU], [tempdb_allocations], [tempdb_current], [blocking_session_id], 
		[blocked_session_count], [reads], [writes], [context_switches], [physical_io], [physical_reads], [query_plan], [locks], 
		[used_memory], [status], [tran_start_time], [open_tran_count], [percent_complete], [host_name], [database_name], [program_name], 
		[additional_info], [start_time], [login_time], [request_id] 
from t_captures
where TimeDurationOrderID = 1
order by timeInMinutes desc;