use tempdb
go

DBCC OPENTRAN ([tempdb]) WITH TABLERESULTS;

EXEC sp_WhoIsActive @find_block_leaders=1, @get_outer_command = 1--, @delta_interval = 30,  --,@get_avg_time=1,
					,@get_task_info = 2 ,@get_additional_info=1
					,@output_column_list = '[coll%][dd hh%][block%][sess%][program_name][login%][program][status][wait_info][sql_text][query_plan][%]'
					,@get_transaction_info=1	
					--,@get_full_inner_text=1
					--,@get_locks=1
					,@get_plans=1
					--,@filter = 4271
					,@filter_type = 'login' ,@filter = 'Lab\adwivedi'

SELECT
    trans.session_id AS [SESSION ID],
    ESes.host_name AS [HOST NAME], login_name AS [Login NAME],
    trans.transaction_id AS [TRANSACTION ID],
    tas.name AS [TRANSACTION NAME], tas.transaction_begin_time AS [TRANSACTION BEGIN TIME],
    tds.database_id AS [DATABASE ID], DBs.name AS [DATABASE NAME]
FROM sys.dm_tran_active_transactions tas
    JOIN sys.dm_tran_session_transactions trans
    ON (trans.transaction_id=tas.transaction_id)
    LEFT OUTER JOIN sys.dm_tran_database_transactions tds
    ON (tas.transaction_id = tds.transaction_id )
    LEFT OUTER JOIN sys.databases AS DBs
    ON tds.database_id = DBs.database_id
    LEFT OUTER JOIN sys.dm_exec_sessions AS ESes
    ON trans.session_id = ESes.session_id
WHERE ESes.session_id IS NOT NULL
	AND DBs.name = DB_NAME()
ORDER BY [TRANSACTION BEGIN TIME] ASC