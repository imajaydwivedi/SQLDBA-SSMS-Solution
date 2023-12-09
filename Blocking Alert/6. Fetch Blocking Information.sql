USE DBA;

SELECT DENSE_RANK()OVER(ORDER BY collection_time ASC) AS CollectionBatchNO, *
  FROM [DBA].[dbo].[WhoIsActive_ResultSets] as r
  WHERE r.blocking_session_id IS NOT NULL OR r.blocked_session_count > 0;

;with t1 as (
SELECT DENSE_RANK()OVER(ORDER BY collection_time ASC) AS CollectionBatchNO, *
  FROM [DBA].[dbo].[WhoIsActive_ResultSets] as r
  WHERE r.blocking_session_id IS NOT NULL OR r.blocked_session_count > 0
)
,t2 as (
select CollectionBatchNO, [dd hh:mm:ss.mss], [dd hh:mm:ss.mss (avg)], session_id, login_name, tasks, tran_log_writes, CPU, tempdb_allocations, tempdb_current, blocking_session_id, blocked_session_count, reads, writes, context_switches, physical_io, physical_reads, used_memory, status, tran_start_time, open_tran_count, percent_complete, host_name, database_name, program_name, start_time, login_time, request_id, collection_time
from t1
)
select distinct program_name from t2 where blocked_session_count > 0

--exec sp_WhatIsRunning 4