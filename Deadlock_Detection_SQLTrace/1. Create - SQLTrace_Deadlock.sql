-- Create a Queue
declare @rc int
declare @TraceID int
declare @maxfilesize bigint
declare @fileFolderPath varchar(500);
declare @tracefile nvarchar(256);

set @fileFolderPath = 'E:\DBA\SQLTrace\'; /* Backslash(\) is Necessary */
SELECT @tracefile = @fileFolderPath+@@serverName+'_'+DATENAME(DAY,GETDATE())+CAST(DATENAME(MONTH,GETDATE()) AS VARCHAR(3))
							+DATENAME(YEAR,GETDATE())+'_'+REPLACE(REPLACE(RIGHT(CONVERT(VARCHAR, GETDATE(), 100),7),':',''), ' ','0');

set @maxfilesize = 500				--	An optimal size for tracing and handling the files

-- Please replace the text InsertFileNameHere, with an appropriate
-- file name prefixed by a path, e.g., c:\MyFolder\MyTrace. The .trc extension
-- will be appended to the filename automatically. 

exec @rc = sp_trace_create @TraceID output, 2 /* rollover*/, @tracefile, @maxfilesize, NULL 
if (@rc != 0) goto error

declare @off bit
declare @on bit
set @off = 0;
set @on = 1;

-- Set the event for Deadlock Graph = 148
exec sp_trace_setevent @TraceID, 148, 1, @on
exec sp_trace_setevent @TraceID, 148, 41, @on
exec sp_trace_setevent @TraceID, 148, 4, @on
exec sp_trace_setevent @TraceID, 148, 12, @on
exec sp_trace_setevent @TraceID, 148, 11, @on
exec sp_trace_setevent @TraceID, 148, 51, @on
exec sp_trace_setevent @TraceID, 148, 14, @on
exec sp_trace_setevent @TraceID, 148, 26, @on
exec sp_trace_setevent @TraceID, 148, 60, @on
exec sp_trace_setevent @TraceID, 148, 64, @on

--	Filter out all sp_trace based commands to the replay does not start this trace
--	Text filters can be expensive so you may want to avoid the filtering and just
--	remote the sp_trace commands from the RML files once processed.
	-- This filter does not work for Deadlock graph
--	exec sp_trace_setfilter @TraceID, 64, 0, 6, N'NT Service\SQLSERVERAGENT'

-- Set the trace status to start
exec sp_trace_setstatus @TraceID, 1
-- Set the trace status to Stop
exec sp_trace_setstatus @TraceID, 0

/*
exec sp_trace_setstatus 2, 0
exec sp_trace_setstatus 2, 2
*/
print 'Issue the following command(s) when you are ready to stop the tracing activity'
print 'exec sp_trace_setstatus ' + cast(@TraceID as varchar) + ', 0'
print 'exec sp_trace_setstatus ' + cast(@TraceID as varchar) + ', 2'

goto finish

error: 
select ErrorCode=@rc

finish: 
select * from ::fn_trace_geteventinfo(@TraceID)
--	select * from sys.traces
select * from sys.fn_trace_getfilterinfo(@TraceID)

print 'exec sp_trace_setstatus ' + cast(@TraceID as varchar) + ', 0'
go

--exec sp_trace_setstatus 2, 1
--exec sp_trace_setstatus 2, 0
--exec msdb..sp_start_job [Stop SQLTrace]