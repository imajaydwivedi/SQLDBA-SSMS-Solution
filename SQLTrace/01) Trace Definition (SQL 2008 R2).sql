/****************************************************/
/* Created by: SQL Server 2008 R2 Profiler          */
/* Date: 06/17/2018  11:21:42 PM         */
/****************************************************/
declare @fileFolderPath varchar(500);
declare @tracefile nvarchar(256);

set @fileFolderPath = 'E:\DBA\SQLTrace\';
SELECT @tracefile = @fileFolderPath+@@serverName+'_'+DATENAME(DAY,GETDATE())+CAST(DATENAME(MONTH,GETDATE()) AS VARCHAR(3))
							+DATENAME(YEAR,GETDATE())+'_'+REPLACE(REPLACE(RIGHT(CONVERT(VARCHAR, GETDATE(), 100),7),':',''), ' ','0');

-- Create a Queue
declare @rc int
declare @TraceID int
declare @maxfilesize bigint
set @maxfilesize = 500 

--Change the InsertFileNameHere to a file name prefixed by a path that is high speed local disk.  
--Do not add the .TRC extension, the server will add it for you.  e.g., 'C:\temp\MyServer_sp_trace'

--exec @rc = sp_trace_create @TraceID output, 0, @tracefile, @maxfilesize, NULL
exec @rc = sp_trace_create @TraceID output, 2 /* rollover*/, @tracefile, @maxfilesize, NULL 
if (@rc != 0) goto error

-- Client side File and Table cannot be scripted

-- Set the events
declare @on bit
set @on = 1
exec sp_trace_setevent @TraceID, 10, 1, @on;      --RPC:Completed.TextData
exec sp_trace_setevent @TraceID, 10, 2, @on;      --RPC:Completed.BinaryData
exec sp_trace_setevent @TraceID, 10, 3, @on;      --RPC:Completed.DatabaseID
exec sp_trace_setevent @TraceID, 10, 4, @on;      --RPC:Completed.TransactionID
exec sp_trace_setevent @TraceID, 10, 6, @on;      --RPC:Completed.NTUserName
exec sp_trace_setevent @TraceID, 10, 7, @on;      --RPC:Completed.NTDomainName
exec sp_trace_setevent @TraceID, 10, 66, @on;     --RPC:Completed.GroupID
exec sp_trace_setevent @TraceID, 10, 48, @on;     --RPC:Completed.RowCounts
exec sp_trace_setevent @TraceID, 10, 49, @on;     --RPC:Completed.RequestID
exec sp_trace_setevent @TraceID, 10, 50, @on;     --RPC:Completed.XactSequence
exec sp_trace_setevent @TraceID, 10, 51, @on;     --RPC:Completed.EventSequence
exec sp_trace_setevent @TraceID, 10, 60, @on;     --RPC:Completed.IsSystem
exec sp_trace_setevent @TraceID, 10, 64, @on;     --RPC:Completed.SessionLoginName
exec sp_trace_setevent @TraceID, 10, 26, @on;     --RPC:Completed.ServerName
exec sp_trace_setevent @TraceID, 10, 27, @on;     --RPC:Completed.EventClass
exec sp_trace_setevent @TraceID, 10, 31, @on;     --RPC:Completed.Error
exec sp_trace_setevent @TraceID, 10, 34, @on;     --RPC:Completed.ObjectName
exec sp_trace_setevent @TraceID, 10, 35, @on;     --RPC:Completed.DatabaseName
exec sp_trace_setevent @TraceID, 10, 41, @on;     --RPC:Completed.LoginSid
exec sp_trace_setevent @TraceID, 10, 14, @on;     --RPC:Completed.StartTime
exec sp_trace_setevent @TraceID, 10, 15, @on;     --RPC:Completed.EndTime
exec sp_trace_setevent @TraceID, 10, 16, @on;     --RPC:Completed.Reads
exec sp_trace_setevent @TraceID, 10, 17, @on;     --RPC:Completed.Writes
exec sp_trace_setevent @TraceID, 10, 18, @on;     --RPC:Completed.CPU
exec sp_trace_setevent @TraceID, 10, 25, @on;     --RPC:Completed.IntegerData
exec sp_trace_setevent @TraceID, 10, 8, @on;      --RPC:Completed.HostName
exec sp_trace_setevent @TraceID, 10, 9, @on;      --RPC:Completed.ClientProcessID
exec sp_trace_setevent @TraceID, 10, 10, @on;     --RPC:Completed.ApplicationName
exec sp_trace_setevent @TraceID, 10, 11, @on;     --RPC:Completed.LoginName
exec sp_trace_setevent @TraceID, 10, 12, @on;     --RPC:Completed.SPID
exec sp_trace_setevent @TraceID, 10, 13, @on;     --RPC:Completed.Duration
exec sp_trace_setevent @TraceID, 12, 1, @on;      --SQL:BatchCompleted.TextData
exec sp_trace_setevent @TraceID, 12, 3, @on;      --SQL:BatchCompleted.DatabaseID
exec sp_trace_setevent @TraceID, 12, 4, @on;      --SQL:BatchCompleted.TransactionID
exec sp_trace_setevent @TraceID, 12, 6, @on;      --SQL:BatchCompleted.NTUserName
exec sp_trace_setevent @TraceID, 12, 7, @on;      --SQL:BatchCompleted.NTDomainName
exec sp_trace_setevent @TraceID, 12, 8, @on;      --SQL:BatchCompleted.HostName
exec sp_trace_setevent @TraceID, 12, 51, @on;     --SQL:BatchCompleted.EventSequence
exec sp_trace_setevent @TraceID, 12, 60, @on;     --SQL:BatchCompleted.IsSystem
exec sp_trace_setevent @TraceID, 12, 64, @on;     --SQL:BatchCompleted.SessionLoginName
exec sp_trace_setevent @TraceID, 12, 66, @on;     --SQL:BatchCompleted.GroupID
exec sp_trace_setevent @TraceID, 12, 31, @on;     --SQL:BatchCompleted.Error
exec sp_trace_setevent @TraceID, 12, 35, @on;     --SQL:BatchCompleted.DatabaseName
exec sp_trace_setevent @TraceID, 12, 41, @on;     --SQL:BatchCompleted.LoginSid
exec sp_trace_setevent @TraceID, 12, 48, @on;     --SQL:BatchCompleted.RowCounts
exec sp_trace_setevent @TraceID, 12, 49, @on;     --SQL:BatchCompleted.RequestID
exec sp_trace_setevent @TraceID, 12, 50, @on;     --SQL:BatchCompleted.XactSequence
exec sp_trace_setevent @TraceID, 12, 15, @on;     --SQL:BatchCompleted.EndTime
exec sp_trace_setevent @TraceID, 12, 16, @on;     --SQL:BatchCompleted.Reads
exec sp_trace_setevent @TraceID, 12, 17, @on;     --SQL:BatchCompleted.Writes
exec sp_trace_setevent @TraceID, 12, 18, @on;     --SQL:BatchCompleted.CPU
exec sp_trace_setevent @TraceID, 12, 26, @on;     --SQL:BatchCompleted.ServerName
exec sp_trace_setevent @TraceID, 12, 27, @on;     --SQL:BatchCompleted.EventClass
exec sp_trace_setevent @TraceID, 12, 9, @on;      --SQL:BatchCompleted.ClientProcessID
exec sp_trace_setevent @TraceID, 12, 10, @on;     --SQL:BatchCompleted.ApplicationName
exec sp_trace_setevent @TraceID, 12, 11, @on;     --SQL:BatchCompleted.LoginName
exec sp_trace_setevent @TraceID, 12, 12, @on;     --SQL:BatchCompleted.SPID
exec sp_trace_setevent @TraceID, 12, 13, @on;     --SQL:BatchCompleted.Duration
exec sp_trace_setevent @TraceID, 12, 14, @on;     --SQL:BatchCompleted.StartTime
exec sp_trace_setevent @TraceID, 13, 1, @on;      --SQL:BatchStarting.TextData
exec sp_trace_setevent @TraceID, 13, 3, @on;      --SQL:BatchStarting.DatabaseID
exec sp_trace_setevent @TraceID, 13, 4, @on;      --SQL:BatchStarting.TransactionID
exec sp_trace_setevent @TraceID, 13, 6, @on;      --SQL:BatchStarting.NTUserName
exec sp_trace_setevent @TraceID, 13, 7, @on;      --SQL:BatchStarting.NTDomainName
exec sp_trace_setevent @TraceID, 13, 8, @on;      --SQL:BatchStarting.HostName
exec sp_trace_setevent @TraceID, 13, 60, @on;     --SQL:BatchStarting.IsSystem
exec sp_trace_setevent @TraceID, 13, 64, @on;     --SQL:BatchStarting.SessionLoginName
exec sp_trace_setevent @TraceID, 13, 66, @on;     --SQL:BatchStarting.GroupID
exec sp_trace_setevent @TraceID, 13, 27, @on;     --SQL:BatchStarting.EventClass
exec sp_trace_setevent @TraceID, 13, 35, @on;     --SQL:BatchStarting.DatabaseName
exec sp_trace_setevent @TraceID, 13, 41, @on;     --SQL:BatchStarting.LoginSid
exec sp_trace_setevent @TraceID, 13, 49, @on;     --SQL:BatchStarting.RequestID
exec sp_trace_setevent @TraceID, 13, 50, @on;     --SQL:BatchStarting.XactSequence
exec sp_trace_setevent @TraceID, 13, 51, @on;     --SQL:BatchStarting.EventSequence
exec sp_trace_setevent @TraceID, 13, 9, @on;      --SQL:BatchStarting.ClientProcessID
exec sp_trace_setevent @TraceID, 13, 10, @on;     --SQL:BatchStarting.ApplicationName
exec sp_trace_setevent @TraceID, 13, 11, @on;     --SQL:BatchStarting.LoginName
exec sp_trace_setevent @TraceID, 13, 12, @on;     --SQL:BatchStarting.SPID
exec sp_trace_setevent @TraceID, 13, 14, @on;     --SQL:BatchStarting.StartTime
exec sp_trace_setevent @TraceID, 13, 26, @on;     --SQL:BatchStarting.ServerName
exec sp_trace_setevent @TraceID, 16, 3, @on;      --Attention.DatabaseID
exec sp_trace_setevent @TraceID, 16, 4, @on;      --Attention.TransactionID
exec sp_trace_setevent @TraceID, 16, 6, @on;      --Attention.NTUserName
exec sp_trace_setevent @TraceID, 16, 7, @on;      --Attention.NTDomainName
exec sp_trace_setevent @TraceID, 16, 8, @on;      --Attention.HostName
exec sp_trace_setevent @TraceID, 16, 9, @on;      --Attention.ClientProcessID
exec sp_trace_setevent @TraceID, 16, 60, @on;     --Attention.IsSystem
exec sp_trace_setevent @TraceID, 16, 64, @on;     --Attention.SessionLoginName
exec sp_trace_setevent @TraceID, 16, 26, @on;     --Attention.ServerName
exec sp_trace_setevent @TraceID, 16, 27, @on;     --Attention.EventClass
exec sp_trace_setevent @TraceID, 16, 35, @on;     --Attention.DatabaseName
exec sp_trace_setevent @TraceID, 16, 41, @on;     --Attention.LoginSid
exec sp_trace_setevent @TraceID, 16, 49, @on;     --Attention.RequestID
exec sp_trace_setevent @TraceID, 16, 51, @on;     --Attention.EventSequence
exec sp_trace_setevent @TraceID, 16, 10, @on;     --Attention.ApplicationName
exec sp_trace_setevent @TraceID, 16, 11, @on;     --Attention.LoginName
exec sp_trace_setevent @TraceID, 16, 12, @on;     --Attention.SPID
exec sp_trace_setevent @TraceID, 16, 13, @on;     --Attention.Duration
exec sp_trace_setevent @TraceID, 16, 14, @on;     --Attention.StartTime
exec sp_trace_setevent @TraceID, 16, 15, @on;     --Attention.EndTime
exec sp_trace_setevent @TraceID, 17, 1, @on;      --ExistingConnection.TextData
exec sp_trace_setevent @TraceID, 17, 2, @on;      --ExistingConnection.BinaryData
exec sp_trace_setevent @TraceID, 17, 3, @on;      --ExistingConnection.DatabaseID
exec sp_trace_setevent @TraceID, 17, 6, @on;      --ExistingConnection.NTUserName
exec sp_trace_setevent @TraceID, 17, 7, @on;      --ExistingConnection.NTDomainName
exec sp_trace_setevent @TraceID, 17, 8, @on;      --ExistingConnection.HostName
exec sp_trace_setevent @TraceID, 17, 66, @on;     --ExistingConnection.GroupID
exec sp_trace_setevent @TraceID, 17, 49, @on;     --ExistingConnection.RequestID
exec sp_trace_setevent @TraceID, 17, 51, @on;     --ExistingConnection.EventSequence
exec sp_trace_setevent @TraceID, 17, 55, @on;     --ExistingConnection.IntegerData2
exec sp_trace_setevent @TraceID, 17, 57, @on;     --ExistingConnection.Type
exec sp_trace_setevent @TraceID, 17, 60, @on;     --ExistingConnection.IsSystem
exec sp_trace_setevent @TraceID, 17, 64, @on;     --ExistingConnection.SessionLoginName
exec sp_trace_setevent @TraceID, 17, 15, @on;     --ExistingConnection.EndTime
exec sp_trace_setevent @TraceID, 17, 25, @on;     --ExistingConnection.IntegerData
exec sp_trace_setevent @TraceID, 17, 26, @on;     --ExistingConnection.ServerName
exec sp_trace_setevent @TraceID, 17, 27, @on;     --ExistingConnection.EventClass
exec sp_trace_setevent @TraceID, 17, 35, @on;     --ExistingConnection.DatabaseName
exec sp_trace_setevent @TraceID, 17, 41, @on;     --ExistingConnection.LoginSid
exec sp_trace_setevent @TraceID, 17, 9, @on;      --ExistingConnection.ClientProcessID
exec sp_trace_setevent @TraceID, 17, 10, @on;     --ExistingConnection.ApplicationName
exec sp_trace_setevent @TraceID, 17, 11, @on;     --ExistingConnection.LoginName
exec sp_trace_setevent @TraceID, 17, 12, @on;     --ExistingConnection.SPID
exec sp_trace_setevent @TraceID, 17, 13, @on;     --ExistingConnection.Duration
exec sp_trace_setevent @TraceID, 17, 14, @on;     --ExistingConnection.StartTime
exec sp_trace_setevent @TraceID, 40, 1, @on;      --SQL:StmtStarting.TextData
exec sp_trace_setevent @TraceID, 40, 3, @on;      --SQL:StmtStarting.DatabaseID
exec sp_trace_setevent @TraceID, 40, 4, @on;      --SQL:StmtStarting.TransactionID
exec sp_trace_setevent @TraceID, 40, 5, @on;      --SQL:StmtStarting.LineNumber
exec sp_trace_setevent @TraceID, 40, 6, @on;      --SQL:StmtStarting.NTUserName
exec sp_trace_setevent @TraceID, 40, 7, @on;      --SQL:StmtStarting.NTDomainName
exec sp_trace_setevent @TraceID, 40, 64, @on;     --SQL:StmtStarting.SessionLoginName
exec sp_trace_setevent @TraceID, 40, 66, @on;     --SQL:StmtStarting.GroupID
exec sp_trace_setevent @TraceID, 40, 49, @on;     --SQL:StmtStarting.RequestID
exec sp_trace_setevent @TraceID, 40, 50, @on;     --SQL:StmtStarting.XactSequence
exec sp_trace_setevent @TraceID, 40, 51, @on;     --SQL:StmtStarting.EventSequence
exec sp_trace_setevent @TraceID, 40, 55, @on;     --SQL:StmtStarting.IntegerData2
exec sp_trace_setevent @TraceID, 40, 60, @on;     --SQL:StmtStarting.IsSystem
exec sp_trace_setevent @TraceID, 40, 61, @on;     --SQL:StmtStarting.Offset
exec sp_trace_setevent @TraceID, 40, 26, @on;     --SQL:StmtStarting.ServerName
exec sp_trace_setevent @TraceID, 40, 27, @on;     --SQL:StmtStarting.EventClass
exec sp_trace_setevent @TraceID, 40, 29, @on;     --SQL:StmtStarting.NestLevel
exec sp_trace_setevent @TraceID, 40, 30, @on;     --SQL:StmtStarting.State
exec sp_trace_setevent @TraceID, 40, 35, @on;     --SQL:StmtStarting.DatabaseName
exec sp_trace_setevent @TraceID, 40, 41, @on;     --SQL:StmtStarting.LoginSid
exec sp_trace_setevent @TraceID, 40, 8, @on;      --SQL:StmtStarting.HostName
exec sp_trace_setevent @TraceID, 40, 9, @on;      --SQL:StmtStarting.ClientProcessID
exec sp_trace_setevent @TraceID, 40, 10, @on;     --SQL:StmtStarting.ApplicationName
exec sp_trace_setevent @TraceID, 40, 11, @on;     --SQL:StmtStarting.LoginName
exec sp_trace_setevent @TraceID, 40, 12, @on;     --SQL:StmtStarting.SPID
exec sp_trace_setevent @TraceID, 40, 14, @on;     --SQL:StmtStarting.StartTime
exec sp_trace_setevent @TraceID, 41, 1, @on;      --SQL:StmtCompleted.TextData
exec sp_trace_setevent @TraceID, 41, 3, @on;      --SQL:StmtCompleted.DatabaseID
exec sp_trace_setevent @TraceID, 41, 4, @on;      --SQL:StmtCompleted.TransactionID
exec sp_trace_setevent @TraceID, 41, 5, @on;      --SQL:StmtCompleted.LineNumber
exec sp_trace_setevent @TraceID, 41, 6, @on;      --SQL:StmtCompleted.NTUserName
exec sp_trace_setevent @TraceID, 41, 7, @on;      --SQL:StmtCompleted.NTDomainName
exec sp_trace_setevent @TraceID, 41, 64, @on;     --SQL:StmtCompleted.SessionLoginName
exec sp_trace_setevent @TraceID, 41, 66, @on;     --SQL:StmtCompleted.GroupID
exec sp_trace_setevent @TraceID, 41, 49, @on;     --SQL:StmtCompleted.RequestID
exec sp_trace_setevent @TraceID, 41, 50, @on;     --SQL:StmtCompleted.XactSequence
exec sp_trace_setevent @TraceID, 41, 51, @on;     --SQL:StmtCompleted.EventSequence
exec sp_trace_setevent @TraceID, 41, 55, @on;     --SQL:StmtCompleted.IntegerData2
exec sp_trace_setevent @TraceID, 41, 60, @on;     --SQL:StmtCompleted.IsSystem
exec sp_trace_setevent @TraceID, 41, 61, @on;     --SQL:StmtCompleted.Offset
exec sp_trace_setevent @TraceID, 41, 26, @on;     --SQL:StmtCompleted.ServerName
exec sp_trace_setevent @TraceID, 41, 27, @on;     --SQL:StmtCompleted.EventClass
exec sp_trace_setevent @TraceID, 41, 29, @on;     --SQL:StmtCompleted.NestLevel
exec sp_trace_setevent @TraceID, 41, 35, @on;     --SQL:StmtCompleted.DatabaseName
exec sp_trace_setevent @TraceID, 41, 41, @on;     --SQL:StmtCompleted.LoginSid
exec sp_trace_setevent @TraceID, 41, 48, @on;     --SQL:StmtCompleted.RowCounts
exec sp_trace_setevent @TraceID, 41, 14, @on;     --SQL:StmtCompleted.StartTime
exec sp_trace_setevent @TraceID, 41, 15, @on;     --SQL:StmtCompleted.EndTime
exec sp_trace_setevent @TraceID, 41, 16, @on;     --SQL:StmtCompleted.Reads
exec sp_trace_setevent @TraceID, 41, 17, @on;     --SQL:StmtCompleted.Writes
exec sp_trace_setevent @TraceID, 41, 18, @on;     --SQL:StmtCompleted.CPU
exec sp_trace_setevent @TraceID, 41, 25, @on;     --SQL:StmtCompleted.IntegerData
exec sp_trace_setevent @TraceID, 41, 8, @on;      --SQL:StmtCompleted.HostName
exec sp_trace_setevent @TraceID, 41, 9, @on;      --SQL:StmtCompleted.ClientProcessID
exec sp_trace_setevent @TraceID, 41, 10, @on;     --SQL:StmtCompleted.ApplicationName
exec sp_trace_setevent @TraceID, 41, 11, @on;     --SQL:StmtCompleted.LoginName
exec sp_trace_setevent @TraceID, 41, 12, @on;     --SQL:StmtCompleted.SPID
exec sp_trace_setevent @TraceID, 41, 13, @on;     --SQL:StmtCompleted.Duration
exec sp_trace_setevent @TraceID, 42, 1, @on;      --SP:Starting.TextData
exec sp_trace_setevent @TraceID, 42, 2, @on;      --SP:Starting.BinaryData
exec sp_trace_setevent @TraceID, 42, 3, @on;      --SP:Starting.DatabaseID
exec sp_trace_setevent @TraceID, 42, 4, @on;      --SP:Starting.TransactionID
exec sp_trace_setevent @TraceID, 42, 5, @on;      --SP:Starting.LineNumber
exec sp_trace_setevent @TraceID, 42, 6, @on;      --SP:Starting.NTUserName
exec sp_trace_setevent @TraceID, 42, 60, @on;     --SP:Starting.IsSystem
exec sp_trace_setevent @TraceID, 42, 62, @on;     --SP:Starting.SourceDatabaseID
exec sp_trace_setevent @TraceID, 42, 64, @on;     --SP:Starting.SessionLoginName
exec sp_trace_setevent @TraceID, 42, 66, @on;     --SP:Starting.GroupID
exec sp_trace_setevent @TraceID, 42, 34, @on;     --SP:Starting.ObjectName
exec sp_trace_setevent @TraceID, 42, 35, @on;     --SP:Starting.DatabaseName
exec sp_trace_setevent @TraceID, 42, 41, @on;     --SP:Starting.LoginSid
exec sp_trace_setevent @TraceID, 42, 49, @on;     --SP:Starting.RequestID
exec sp_trace_setevent @TraceID, 42, 50, @on;     --SP:Starting.XactSequence
exec sp_trace_setevent @TraceID, 42, 51, @on;     --SP:Starting.EventSequence
exec sp_trace_setevent @TraceID, 42, 14, @on;     --SP:Starting.StartTime
exec sp_trace_setevent @TraceID, 42, 22, @on;     --SP:Starting.ObjectID
exec sp_trace_setevent @TraceID, 42, 26, @on;     --SP:Starting.ServerName
exec sp_trace_setevent @TraceID, 42, 27, @on;     --SP:Starting.EventClass
exec sp_trace_setevent @TraceID, 42, 28, @on;     --SP:Starting.ObjectType
exec sp_trace_setevent @TraceID, 42, 29, @on;     --SP:Starting.NestLevel
exec sp_trace_setevent @TraceID, 42, 7, @on;      --SP:Starting.NTDomainName
exec sp_trace_setevent @TraceID, 42, 8, @on;      --SP:Starting.HostName
exec sp_trace_setevent @TraceID, 42, 9, @on;      --SP:Starting.ClientProcessID
exec sp_trace_setevent @TraceID, 42, 10, @on;     --SP:Starting.ApplicationName
exec sp_trace_setevent @TraceID, 42, 11, @on;     --SP:Starting.LoginName
exec sp_trace_setevent @TraceID, 42, 12, @on;     --SP:Starting.SPID
exec sp_trace_setevent @TraceID, 43, 1, @on;      --SP:Completed.TextData
exec sp_trace_setevent @TraceID, 43, 2, @on;      --SP:Completed.BinaryData
exec sp_trace_setevent @TraceID, 43, 3, @on;      --SP:Completed.DatabaseID
exec sp_trace_setevent @TraceID, 43, 4, @on;      --SP:Completed.TransactionID
exec sp_trace_setevent @TraceID, 43, 5, @on;      --SP:Completed.LineNumber
exec sp_trace_setevent @TraceID, 43, 6, @on;      --SP:Completed.NTUserName
exec sp_trace_setevent @TraceID, 43, 66, @on;     --SP:Completed.GroupID
exec sp_trace_setevent @TraceID, 43, 49, @on;     --SP:Completed.RequestID
exec sp_trace_setevent @TraceID, 43, 50, @on;     --SP:Completed.XactSequence
exec sp_trace_setevent @TraceID, 43, 51, @on;     --SP:Completed.EventSequence
exec sp_trace_setevent @TraceID, 43, 60, @on;     --SP:Completed.IsSystem
exec sp_trace_setevent @TraceID, 43, 62, @on;     --SP:Completed.SourceDatabaseID
exec sp_trace_setevent @TraceID, 43, 64, @on;     --SP:Completed.SessionLoginName
exec sp_trace_setevent @TraceID, 43, 28, @on;     --SP:Completed.ObjectType
exec sp_trace_setevent @TraceID, 43, 29, @on;     --SP:Completed.NestLevel
exec sp_trace_setevent @TraceID, 43, 34, @on;     --SP:Completed.ObjectName
exec sp_trace_setevent @TraceID, 43, 35, @on;     --SP:Completed.DatabaseName
exec sp_trace_setevent @TraceID, 43, 41, @on;     --SP:Completed.LoginSid
exec sp_trace_setevent @TraceID, 43, 48, @on;     --SP:Completed.RowCounts
exec sp_trace_setevent @TraceID, 43, 13, @on;     --SP:Completed.Duration
exec sp_trace_setevent @TraceID, 43, 14, @on;     --SP:Completed.StartTime
exec sp_trace_setevent @TraceID, 43, 15, @on;     --SP:Completed.EndTime
exec sp_trace_setevent @TraceID, 43, 22, @on;     --SP:Completed.ObjectID
exec sp_trace_setevent @TraceID, 43, 26, @on;     --SP:Completed.ServerName
exec sp_trace_setevent @TraceID, 43, 27, @on;     --SP:Completed.EventClass
exec sp_trace_setevent @TraceID, 43, 7, @on;      --SP:Completed.NTDomainName
exec sp_trace_setevent @TraceID, 43, 8, @on;      --SP:Completed.HostName
exec sp_trace_setevent @TraceID, 43, 9, @on;      --SP:Completed.ClientProcessID
exec sp_trace_setevent @TraceID, 43, 10, @on;     --SP:Completed.ApplicationName
exec sp_trace_setevent @TraceID, 43, 11, @on;     --SP:Completed.LoginName
exec sp_trace_setevent @TraceID, 43, 12, @on;     --SP:Completed.SPID
exec sp_trace_setevent @TraceID, 44, 1, @on;      --SP:StmtStarting.TextData
exec sp_trace_setevent @TraceID, 44, 3, @on;      --SP:StmtStarting.DatabaseID
exec sp_trace_setevent @TraceID, 44, 4, @on;      --SP:StmtStarting.TransactionID
exec sp_trace_setevent @TraceID, 44, 5, @on;      --SP:StmtStarting.LineNumber
exec sp_trace_setevent @TraceID, 44, 6, @on;      --SP:StmtStarting.NTUserName
exec sp_trace_setevent @TraceID, 44, 7, @on;      --SP:StmtStarting.NTDomainName
exec sp_trace_setevent @TraceID, 44, 55, @on;     --SP:StmtStarting.IntegerData2
exec sp_trace_setevent @TraceID, 44, 60, @on;     --SP:StmtStarting.IsSystem
exec sp_trace_setevent @TraceID, 44, 61, @on;     --SP:StmtStarting.Offset
exec sp_trace_setevent @TraceID, 44, 62, @on;     --SP:StmtStarting.SourceDatabaseID
exec sp_trace_setevent @TraceID, 44, 64, @on;     --SP:StmtStarting.SessionLoginName
exec sp_trace_setevent @TraceID, 44, 66, @on;     --SP:StmtStarting.GroupID
exec sp_trace_setevent @TraceID, 44, 34, @on;     --SP:StmtStarting.ObjectName
exec sp_trace_setevent @TraceID, 44, 35, @on;     --SP:StmtStarting.DatabaseName
exec sp_trace_setevent @TraceID, 44, 41, @on;     --SP:StmtStarting.LoginSid
exec sp_trace_setevent @TraceID, 44, 49, @on;     --SP:StmtStarting.RequestID
exec sp_trace_setevent @TraceID, 44, 50, @on;     --SP:StmtStarting.XactSequence
exec sp_trace_setevent @TraceID, 44, 51, @on;     --SP:StmtStarting.EventSequence
exec sp_trace_setevent @TraceID, 44, 22, @on;     --SP:StmtStarting.ObjectID
exec sp_trace_setevent @TraceID, 44, 26, @on;     --SP:StmtStarting.ServerName
exec sp_trace_setevent @TraceID, 44, 27, @on;     --SP:StmtStarting.EventClass
exec sp_trace_setevent @TraceID, 44, 28, @on;     --SP:StmtStarting.ObjectType
exec sp_trace_setevent @TraceID, 44, 29, @on;     --SP:StmtStarting.NestLevel
exec sp_trace_setevent @TraceID, 44, 30, @on;     --SP:StmtStarting.State
exec sp_trace_setevent @TraceID, 44, 8, @on;      --SP:StmtStarting.HostName
exec sp_trace_setevent @TraceID, 44, 9, @on;      --SP:StmtStarting.ClientProcessID
exec sp_trace_setevent @TraceID, 44, 10, @on;     --SP:StmtStarting.ApplicationName
exec sp_trace_setevent @TraceID, 44, 11, @on;     --SP:StmtStarting.LoginName
exec sp_trace_setevent @TraceID, 44, 12, @on;     --SP:StmtStarting.SPID
exec sp_trace_setevent @TraceID, 44, 14, @on;     --SP:StmtStarting.StartTime
exec sp_trace_setevent @TraceID, 45, 1, @on;      --SP:StmtCompleted.TextData
exec sp_trace_setevent @TraceID, 45, 3, @on;      --SP:StmtCompleted.DatabaseID
exec sp_trace_setevent @TraceID, 45, 4, @on;      --SP:StmtCompleted.TransactionID
exec sp_trace_setevent @TraceID, 45, 5, @on;      --SP:StmtCompleted.LineNumber
exec sp_trace_setevent @TraceID, 45, 6, @on;      --SP:StmtCompleted.NTUserName
exec sp_trace_setevent @TraceID, 45, 7, @on;      --SP:StmtCompleted.NTDomainName
exec sp_trace_setevent @TraceID, 45, 55, @on;     --SP:StmtCompleted.IntegerData2
exec sp_trace_setevent @TraceID, 45, 60, @on;     --SP:StmtCompleted.IsSystem
exec sp_trace_setevent @TraceID, 45, 61, @on;     --SP:StmtCompleted.Offset
exec sp_trace_setevent @TraceID, 45, 62, @on;     --SP:StmtCompleted.SourceDatabaseID
exec sp_trace_setevent @TraceID, 45, 64, @on;     --SP:StmtCompleted.SessionLoginName
exec sp_trace_setevent @TraceID, 45, 66, @on;     --SP:StmtCompleted.GroupID
exec sp_trace_setevent @TraceID, 45, 35, @on;     --SP:StmtCompleted.DatabaseName
exec sp_trace_setevent @TraceID, 45, 41, @on;     --SP:StmtCompleted.LoginSid
exec sp_trace_setevent @TraceID, 45, 48, @on;     --SP:StmtCompleted.RowCounts
exec sp_trace_setevent @TraceID, 45, 49, @on;     --SP:StmtCompleted.RequestID
exec sp_trace_setevent @TraceID, 45, 50, @on;     --SP:StmtCompleted.XactSequence
exec sp_trace_setevent @TraceID, 45, 51, @on;     --SP:StmtCompleted.EventSequence
exec sp_trace_setevent @TraceID, 45, 25, @on;     --SP:StmtCompleted.IntegerData
exec sp_trace_setevent @TraceID, 45, 26, @on;     --SP:StmtCompleted.ServerName
exec sp_trace_setevent @TraceID, 45, 27, @on;     --SP:StmtCompleted.EventClass
exec sp_trace_setevent @TraceID, 45, 28, @on;     --SP:StmtCompleted.ObjectType
exec sp_trace_setevent @TraceID, 45, 29, @on;     --SP:StmtCompleted.NestLevel
exec sp_trace_setevent @TraceID, 45, 34, @on;     --SP:StmtCompleted.ObjectName
exec sp_trace_setevent @TraceID, 45, 14, @on;     --SP:StmtCompleted.StartTime
exec sp_trace_setevent @TraceID, 45, 15, @on;     --SP:StmtCompleted.EndTime
exec sp_trace_setevent @TraceID, 45, 16, @on;     --SP:StmtCompleted.Reads
exec sp_trace_setevent @TraceID, 45, 17, @on;     --SP:StmtCompleted.Writes
exec sp_trace_setevent @TraceID, 45, 18, @on;     --SP:StmtCompleted.CPU
exec sp_trace_setevent @TraceID, 45, 22, @on;     --SP:StmtCompleted.ObjectID
exec sp_trace_setevent @TraceID, 45, 8, @on;      --SP:StmtCompleted.HostName
exec sp_trace_setevent @TraceID, 45, 9, @on;      --SP:StmtCompleted.ClientProcessID
exec sp_trace_setevent @TraceID, 45, 10, @on;     --SP:StmtCompleted.ApplicationName
exec sp_trace_setevent @TraceID, 45, 11, @on;     --SP:StmtCompleted.LoginName
exec sp_trace_setevent @TraceID, 45, 12, @on;     --SP:StmtCompleted.SPID
exec sp_trace_setevent @TraceID, 45, 13, @on;     --SP:StmtCompleted.Duration
exec sp_trace_setevent @TraceID, 162, 1, @on;     --User Error Message.TextData
exec sp_trace_setevent @TraceID, 162, 3, @on;     --User Error Message.DatabaseID
exec sp_trace_setevent @TraceID, 162, 4, @on;     --User Error Message.TransactionID
exec sp_trace_setevent @TraceID, 162, 6, @on;     --User Error Message.NTUserName
exec sp_trace_setevent @TraceID, 162, 7, @on;     --User Error Message.NTDomainName
exec sp_trace_setevent @TraceID, 162, 8, @on;     --User Error Message.HostName
exec sp_trace_setevent @TraceID, 162, 9, @on;     --User Error Message.ClientProcessID
exec sp_trace_setevent @TraceID, 162, 10, @on;    --User Error Message.ApplicationName
exec sp_trace_setevent @TraceID, 162, 11, @on;    --User Error Message.LoginName
exec sp_trace_setevent @TraceID, 162, 12, @on;    --User Error Message.SPID
exec sp_trace_setevent @TraceID, 162, 14, @on;    --User Error Message.StartTime
exec sp_trace_setevent @TraceID, 162, 20, @on;    --User Error Message.Severity
exec sp_trace_setevent @TraceID, 162, 26, @on;    --User Error Message.ServerName
exec sp_trace_setevent @TraceID, 162, 27, @on;    --User Error Message.EventClass
exec sp_trace_setevent @TraceID, 162, 30, @on;    --User Error Message.State
exec sp_trace_setevent @TraceID, 162, 31, @on;    --User Error Message.Error
exec sp_trace_setevent @TraceID, 162, 35, @on;    --User Error Message.DatabaseName
exec sp_trace_setevent @TraceID, 162, 41, @on;    --User Error Message.LoginSid
exec sp_trace_setevent @TraceID, 162, 49, @on;    --User Error Message.RequestID
exec sp_trace_setevent @TraceID, 162, 50, @on;    --User Error Message.XactSequence
exec sp_trace_setevent @TraceID, 162, 51, @on;    --User Error Message.EventSequence
exec sp_trace_setevent @TraceID, 162, 60, @on;    --User Error Message.IsSystem
exec sp_trace_setevent @TraceID, 162, 64, @on;    --User Error Message.SessionLoginName
exec sp_trace_setevent @TraceID, 162, 66, @on;    --User Error Message.GroupID
/*
-- Set the Filters on Reads >= 10000
declare @intfilter int
declare @bigintfilter bigint

set @bigintfilter = 10000
exec sp_trace_setfilter @TraceID, 16, 0, 4, @bigintfilter
*/

-- Set Filter on LoginName = 'Contso\WindowsLoginName'
exec sp_trace_setfilter @TraceID, 11, 0, 0, N'Contso\WindowsLoginName';

-- Set Filter on DatabaseName like 'DBAMusicShipping_%'
exec sp_trace_setfilter @TraceID, 35, 0, 6, N'DBAMusicShipping%';

-- Set Filter on ApplicationName = '.Net SqlClient Data Provider'
exec sp_trace_setfilter @TraceID, 10, 0, 0, N'.Net SqlClient Data Provider';

-- Set the trace status to start
exec sp_trace_setstatus @TraceID, 1

-- display trace id for future references
select TraceID=@TraceID
goto finish

error: 
select ErrorCode=@rc

finish: 
go
