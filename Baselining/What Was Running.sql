SELECT  DENSE_RANK()OVER(ORDER BY collection_Time ASC) AS CollectionBatch, [collection_time], [TimeInMinutes], 
		[dd hh:mm:ss.mss], [dd hh:mm:ss.mss (avg)], [session_id], [sql_text], [sql_command], [login_name], 
		[wait_info], [tasks], [tran_log_writes], [CPU], [tempdb_allocations], [tempdb_current], [blocking_session_id], 
		[blocked_session_count], [reads], [writes], [context_switches], [physical_io], [physical_reads], [query_plan], [locks], 
		[used_memory], [status], [tran_start_time], [open_tran_count], [percent_complete], [host_name], [database_name], [program_name], 
		[additional_info], [start_time], [login_time], [request_id]
FROM [DBA].[dbo].WhoIsActive_ResultSets AS r
--WHERE r.collection_Time >= '2019-04-23 02:30:00.000' AND r.collection_Time <= '2019-04-23 03:30:00.000'
WHERE r.collection_Time >= DATEADD(HOUR,-8,getdate())
--AND r.program_name <> 'Microsoft® Windows® Operating System'
ORDER BY collection_Time ASC --collection_Time, [TimeInMinutes] desc
GO

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

--	select * from DBA..whoisactive_resultsets r where r.collection_time = '2019-04-29 18:30:01.307' and session_id = 80;
--	select * from DBA..whoisactive_resultsets r where r.collection_time = '2019-04-26 17:15:01.437' and session_id = 66;
