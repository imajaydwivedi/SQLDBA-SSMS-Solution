declare @sql nvarchar(max);
declare @params nvarchar(max);

set quoted_identifier off;
set @sql = "
declare @_latest_InsertedDate_UTC datetime;

select @_latest_InsertedDate_UTC = max(InsertedDate_UTC)
FROM DBA_Admin.dbo.LOG_TRANSACTIONAL_REPLICATION_UNDISTRIBUTED_COMMANDS_History;

SELECT	InsertedDate_UTC AS time, 
		PublisherDB, Publication, Subscriber, 
		--[metric] = '[' + PublisherDB + '].[' + Publication + '].[' + Subscriber + ']', 
		[Latency_sec] = EstimatedProcessTime_sec
FROM DBA_Admin.dbo.LOG_TRANSACTIONAL_REPLICATION_UNDISTRIBUTED_COMMANDS_History
WHERE 1=1
and InsertedDate_UTC = @_latest_InsertedDate_UTC
order by  InsertedDate_UTC
"
set quoted_identifier on;

exec [10.253.33.229].[DBA_Admin].dbo.sp_executesql @sql;
go

