--	Find all running SQL Traces on Server
	--	[traceid] = 1 is System Trace (Default)
SELECT getdate() as currentTime, @@servername as srvName, * FROM ::fn_trace_getinfo(0);

select @@servername as srvName, t.id, t.status, t.path, t.start_time, t.last_event_time 
from sys.traces as t

--	To Start trace
exec sp_trace_setstatus 2, 1;

--	To Stop running trace
	-- Stop [traceid] = 2 SQL Trace
exec sp_trace_setstatus 2, 0;
	
--	To Remove it entirely 
exec sp_trace_setstatus 2, 2;

--	Command to perform ReadTrace
"C:\Program Files\Microsoft Corporation\RMLUtils\ReadTrace.exe" -IG:\DBA\SQLTrace\SQLTrace\DbServerName01_18Jun2018_1124PM.trc -oG:\DBA\SQLTrace -f
"C:\Program Files\Microsoft Corporation\RMLUtils\ReadTrace.exe" -IE:\PerformanceAnalysis\2018, June 18 - Publisher Trace\DbServerName01_19Jun2018_0230AM\DbServerName01_19Jun2018_0230AM.trc -oE:\PerformanceAnalysis -f

--	Find Common Trace Events for Query Performance
select * from sys.trace_events te where te.trace_event_id in (10,12,13,16,17,40,41,42,43,44,45,98,122);
select * from sys.trace_events te where te.name like '%user%';

select	eb.trace_event_id, eb.trace_column_id, tc.name, te.name
		,cast('exec sp_trace_setevent @TraceID, '+cast(eb.trace_event_id as varchar(5))+', '+cast(eb.trace_column_id as varchar(5))+', @on;' as char(50))+'--'+te.name+'.'+tc.name as [sp_trace_setevent]
from sys.trace_event_bindings eb join sys.trace_columns tc on tc.trace_column_id = eb.trace_column_id join sys.trace_events te on te.trace_event_id = eb.trace_event_id
--where eb.trace_event_id in (10,12,13,16,17,40,41,42,43,44,45);
where eb.trace_event_id in (162);

-- Find Trace Events for Running Trace
select * from sys.trace_events te where te.trace_event_id in (select eventid from sys.fn_trace_geteventinfo ( 2 ));

-- Find Trace Filters for Running Trace
select * from fn_trace_getfilterinfo (2);
select * from sys.trace_columns tc where tc.trace_column_id in (select columnid from fn_trace_getfilterinfo (2));
select * from sys.trace_columns tc where tc.name like '%ApplicationName%'


-- Get Collected Trace into SQL Table
SELECT * INTO SQLTraceResults_EU_Apr29
FROM ::fn_trace_gettable('H:\Performance-Issues\Data-Collections\DbServerName01\DbServerName01_29Apr2019_0220PM.trc', default)

