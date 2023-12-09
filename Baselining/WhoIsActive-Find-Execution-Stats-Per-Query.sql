use DBA
go

;WITH T_Batch_Query AS
(
	SELECT  DENSE_RANK()OVER(ORDER BY r.session_id, r.program_name, CAST(r.sql_command AS NVARCHAR(MAX)) ) AS SQLBatchID,
			DENSE_RANK()OVER(ORDER BY r.session_id, r.program_name, CAST(r.sql_command AS NVARCHAR(MAX)), additional_info.value('(/additional_info/sql_handle)[1]','varchar(500)') ) AS SQLBatchQueryID,
			ROW_NUMBER()OVER(PARTITION BY r.session_id, r.program_name, CAST(r.sql_command AS NVARCHAR(MAX)), additional_info.value('(/additional_info/sql_handle)[1]','varchar(500)') ORDER BY collection_Time ASC) AS SQLBatchQuery_RANK,
			[collection_time], [TimeInMinutes], [dd hh:mm:ss.mss], [session_id], [sql_text], [sql_command], [login_name], 
			[wait_info], [tasks], [tran_log_writes], [CPU], [tempdb_allocations], [tempdb_current], [blocking_session_id], 
			[blocked_session_count], [reads], [writes], [context_switches], [physical_io], [physical_reads], [query_plan], [locks], 
			[used_memory], [status], [tran_start_time], [open_tran_count], [percent_complete], [host_name], [database_name], [program_name], 
			[additional_info], [start_time], [login_time], [request_id]
			,sql_handle = additional_info.value('(/additional_info/sql_handle)[1]','varchar(500)')
	FROM [DBA].[dbo].WhoIsActive_ResultSets AS r
	WHERE r.program_name like 'SQL Job = IncomeTax!_Return!_caller!_%' ESCAPE '!'
	AND	r.sql_command IS NOT NULL
)
SELECT	TOP 100 [dd hh:mm:ss.mss], [session_id], [sql_text], [sql_command], 
			[TimeInMinutes] = datediff(MINute,m.collection_time_START, m.collection_time_FINISH), m.collection_time_START, m.collection_time_FINISH,
			[login_name], [wait_info], [tasks], [tran_log_writes], [CPU], [tempdb_allocations], [tempdb_current], [blocking_session_id], 
			[blocked_session_count], [reads], [writes], [context_switches], [physical_io], [physical_reads], [query_plan], [locks], 
			[used_memory], [status], [tran_start_time], [open_tran_count], [percent_complete], [host_name], [database_name], [program_name], 
			[additional_info], [start_time], [login_time], [request_id]
FROM	T_Batch_Query as r
OUTER APPLY
	(
		SELECT	MAX(i.collection_time) AS collection_time_FINISH, MIN(i.collection_time) AS collection_time_START
				,MAX([TimeInMinutes]) AS [TimeInMinutes]
		FROM	T_Batch_Query as i
		WHERE	i.SQLBatchID = r.SQLBatchID
			AND	i.SQLBatchQueryID = r.SQLBatchQueryID
	) as m
WHERE r.SQLBatchQuery_RANK = 1
ORDER BY r.SQLBatchID, r.collection_time, r.SQLBatchQueryID, r.SQLBatchQuery_RANK
