--	Get trace events and columns
select	e.trace_event_id, e.name
		,c.name as columnName ,c.trace_column_id ,c.type_name ,c.is_filterable				
from sys.trace_event_bindings as b 
inner join
	sys.trace_events as e
	on	e.trace_event_id = b.trace_event_id
inner join
	sys.trace_columns as c
	on	c.trace_column_id = b.trace_column_id
where e.name like 'Deadlock graph'
order by trace_event_id, trace_column_id;

/*	--	https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-trace-setfilter-transact-sql?view=sql-server-2017
sp_trace_setfilter [ @traceid = ] trace_id   
          , [ @columnid = ] column_id  
          , [ @logical_operator = ] logical_operator  
          , [ @comparison_operator = ] comparison_operator  
          , [ @value = ] value  
*/

select * from sys.traces
select * from sys.fn_trace_getfilterinfo(2)

select  RowNumber, e.name as EventName, case when Error = 0 then 'Ok' when Error = 1 then 'Error' when Error = 2 then 'Abort' else null end as Error_Message,
		DatabaseName, case when LoginName is null then NTDomainName+'\'+NTUserName else LoginName end as LoginName, HostName, ApplicationName, t.TextData,
		t.StartTime, t.EndTime, t.Duration, t.ObjectName, t.CPU, t.Reads, t.RowCounts, t.Writes
from DBA.[dbo].[SQLTrace_Galaxy_Richmedia_Timeout] t left join sys.trace_events e on e.trace_event_id = t.EventClass
--where t.ApplicationName like '%Management Studio%'
--and DatabaseName in ('Stackoverflow')
--and HostName in ('MSI_Laptop')
--and LoginName in ('sa')
--and TextData like '%usp%'
WHERE (Error is not null and Error in (1, 2))
order by RowNumber
go

declare @path varchar(255);
set @path = 'E:\DBA\SQLTrace\MSI_Laptop_10Sep2018_0143PM.trc'
if exists (select * from sys.traces t where t.path = @path and status = 0)
begin
	declare @traceID int
	select @traceID = id from sys.traces t where t.path = @path and status = 0;
	exec sp_trace_setstatus @traceID, 1;
end
go

select * from sys.traces

if exists (select * from sys.traces t where t.path like 'g:\DBA\SQLTrace\CMP_OutOfSync_DeadlockIssue_%' and status = 1)
begin
	declare @traceID int
	select @traceID = id from sys.traces t where t.path like 'g:\DBA\SQLTrace\CMP_OutOfSync_DeadlockIssue_YourDbServerName_14Sep2018_1047AM.trc' and status = 1;
	exec sp_trace_setstatus @traceID, 0;
end
select * from sys.traces