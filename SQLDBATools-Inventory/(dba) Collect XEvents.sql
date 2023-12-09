/*
	https://www.sqlservercentral.com/articles/performance-tuning-using-extended-events-part-1
*/
--	Deadlocks
CREATE EVENT SESSION [Deadlocks] ON SERVER
ADD EVENT sqlserver.xml_deadlock_report
ADD TARGET package0.event_file(SET filename=N'Deadlocks', max_file_size=(250), max_rollover_files=(3))
WITH (MAX_MEMORY=4096 KB, EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY=30 SECONDS, MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE, TRACK_CAUSALITY=ON, STARTUP_STATE=ON)
GO
ALTER EVENT SESSION [Deadlocks] ON SERVER STATE = START
GO

-- Application Abort (A.K.A. The Time Out)
CREATE EVENT SESSION [TimeOuts] ON SERVER
ADD EVENT sqlserver.rpc_completed(SET collect_output_parameters=(1)
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.is_system,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.session_id)
    WHERE ([result]=(2)))
ADD TARGET package0.event_file(SET filename=N'TimeOuts',max_file_size=(250),max_rollover_files=(3))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
GO
ALTER EVENT SESSION [TimeOuts] ON SERVER STATE = START
GO

-- Blocking
EXEC sp_configure 'show advanced options',1;
GO
RECONFIGURE;
GO
EXEC sp_configure 'blocked process threshold',20;
GO
RECONFIGURE;
GO

CREATE EVENT SESSION [Blocking] ON SERVER
ADD EVENT sqlserver.blocked_process_report
ADD TARGET package0.event_file(SET filename=N'Blocking',max_file_size=(250),max_rollover_files=(3))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
GO
ALTER EVENT SESSION [Blocking] ON SERVER STATE = START
GO

-- Long Running Queries
CREATE EVENT SESSION [DurationGT25Seconds] ON SERVER 
ADD EVENT sqlserver.rpc_completed(SET collect_output_parameters=(1),collect_statement=(1)
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.is_system,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.session_id)
    WHERE ([duration]>(25000000))),
ADD EVENT sqlserver.sql_batch_completed(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.is_system,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.session_id)
    WHERE ([duration]>(25000000))),
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.database_name,sqlserver.is_system,sqlserver.nt_username,sqlserver.plan_handle,sqlserver.session_id)
    WHERE ([duration]>(25000000)))
ADD TARGET package0.event_file(SET filename=N'DurationGT25Seconds',max_file_size=(250),max_rollover_files=(3))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=ON)
GO
ALTER EVENT SESSION [DurationGT25Seconds] ON SERVER STATE = START
GO

