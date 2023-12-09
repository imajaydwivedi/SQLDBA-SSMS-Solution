USE SQLWATCH;
GO

select * from dbo.[sqlwatch_app_log] where process_message_type = 'ERROR'
select check_query
from dbo.sqlwatch_config_check
where check_id = -21

SELECT isnull(max(datediff(second, transaction_begin_time, getdate())), 0)
FROM sys.dm_tran_active_transactions at
INNER JOIN sys.dm_tran_session_transactions st ON at.transaction_id = st.transaction_id
LEFT JOIN sys.dm_exec_requests r ON r.session_id = st.session_id
WHERE st.session_id <> @@SPID
	AND st.session_id > 50
	AND r.last_wait_type NOT IN ('BROKER_RECEIVE_WAITFOR')

/*
update cc
set check_query = 'select @output=isnull(max(datediff(minute,backup_finish_date,getdate())),999)  from sys.databases d  left join msdb.dbo.backupset bs   on bs.database_name = d.name   and bs.type = ''L''  where d.recovery_model_desc <> ''SIMPLE''  and d.name not in (''tempdb'')'
--select * 
from dbo.sqlwatch_config_check as cc
where cc.check_id in (-17);

delete
--select * 
from dbo.[sqlwatch_app_log] where process_message_type = 'ERROR' AND process_stage = '6DC68414-915F-4B52-91B6-4D0B6018243B'

*/