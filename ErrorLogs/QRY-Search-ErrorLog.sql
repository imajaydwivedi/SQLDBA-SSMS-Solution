--	Check-SQLServerAvailability
SET nocount on;

if exists (select * from sys.databases d where d.state_desc NOT IN ('ONLINE','OFFLINE'))
begin
	select @@servername as srv, d.name as [database_name], state_desc
			--,[Uptime (hh:mm:ss)] = convert(varchar,getdate()-d.create_date,108), create_date
	FROM sys.databases as d 
	WHERE d.state_desc NOT IN ('ONLINE','OFFLINE')
end

declare @start_time datetime, @end_time datetime, @err_msg_1 nvarchar(256) = null, @err_msg_2 nvarchar(256) = null;
--set @start_time = '2023-09-27 06:14' --  August 22, 2020 05:16:00
--set @time = DATEADD(HOUR,-1,getdate());
set @start_time = DATEADD(HOUR,-2*1,getdate());
--set @end_time = '2023-09-27 06:35';
set @end_time = GETDATE()
--set @end_time = DATEADD(minute,30*1,@start_time)
--set @err_msg_1 = 'Unable to open the physical file'
--set @err_msg_1 = 'There is insufficient system memory in resource pool'
--set @err_msg_1 = 'Internal'
--set @err_msg_1 = 'config'
--set @err_msg_1 = 'Database ''StackOverflow'' is already open and can only have one user at a time.'
--set @err_msg_1 = 'has been rejected due to breached concurrent connection limit';

--EXEC master.dbo.xp_enumerrorlogs
declare @NumErrorLogs int;
declare @ErrorLogPath varchar(2000);
begin try
	exec master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', 
								N'Software\Microsoft\MSSQLServer\MSSQLServer',
								N'NumErrorLogs', 
								@NumErrorLogs OUTPUT;
end try
begin catch
end catch
if OBJECT_ID('tempdb..#errorlog') is not null	drop table #errorlog;
create table #errorlog (LogDate datetime2 not null, ProcessInfo varchar(200) not null, Text varchar(2000) not null);

insert #errorlog
exec sp_readerrorlog 0,1,'Log\ERRORLOG','-e'

select @ErrorLogPath = REPLACE(LTRIM(RTRIM(REPLACE(REPLACE(SUBSTRING(Text, CHARINDEX('-e ',Text)+3, CHARINDEX('-l ', Text)-CHARINDEX('-e ',Text)-3),CHAR(10),''),CHAR(13),''))), '\ERRORLOG','')
from #errorlog;

truncate table #errorlog;
--SET  @ErrorLogPath = REPLACE(@ErrorLogPath, '\ERRORLOG','');

if object_id('tempdb..#log_folder_files') is not null
	drop table #log_folder_files;
create table #log_folder_files (subdirectory varchar(255), depth tinyint, [is_file] tinyint);

insert #log_folder_files
exec xp_dirtree @ErrorLogPath, 1, 1;

select @NumErrorLogs = isnull(@NumErrorLogs,COUNT(*)+1) from #log_folder_files
where subdirectory like 'ERRORLOG.%'

print char(13)+'[@ErrorLogPath] = '''+@ErrorLogPath+'''';
print '[@NumErrorLogs] = '+convert(varchar,@NumErrorLogs);

set @NumErrorLogs = ISNULL(@NumErrorLogs,6);
set @NumErrorLogs = case when @NumErrorLogs > 7 then 7 else @NumErrorLogs end

declare @counter int = 0;
while @counter < @NumErrorLogs
begin
	begin try
		print 'Scan log file '+convert(varchar,@counter)
		insert #errorlog
		EXEC master.dbo.xp_readerrorlog @counter, 1, @err_msg_1, @err_msg_2, @start_time, @end_time, "asc";
		--print 'EXEC master.dbo.xp_readerrorlog '+cast(@counter as varchar)+', 1, '+isnull(''''+@err_msg_1+'''','NULL')+', '+isnull(''''+@err_msg_1+'''','NULL')+', @start_time, @end_time, "asc"';
	end try
	begin catch
		print 'error'
	end catch
	set @counter += 1;

	if exists (select * from #errorlog where LogDate > @end_time)
		break;
end


select lower(convert(varchar,SERVERPROPERTY('MachineName'))) as ServerName,
		ROW_NUMBER()over(order by LogDate asc) as id,
		datediff(minute,LogDate,getdate()) as [-Time(min)],
			--master.dbo.time2duration(LogDate,'datetime') as [Log-Duration],
		LogDate, ProcessInfo, 
		[************************************* TEXT *********************************************************************************] = Text
--select left(Text,45) as Text, max(LogDate) as LogDate_max, min(LogDate) as LogDate_min, COUNT(*) as occurrences
from #errorlog as e
where 1 = 1
--and e.Text like '%has been rejected due to breached concurrent connection limit%'
and	e.ProcessInfo not in ('Backup')
and e.ProcessInfo not in ('Logon')
and e.Text not like 'Error: 18456%'
and not (e.ProcessInfo = 'Backup' and (e.Text like 'Log was backed up%' or e.Text like 'Database backed up. %' or e.Text like 'BACKUP DATABASE successfully%') )
and e.Text not like 'Parallel redo is shutdown for database%'
and e.Text not like 'Parallel redo is started for database%'
--and e.Text not like 'Database % is a cloned database. This database should be used for diagnostic purposes only and is not supported for use in a production environment.'
--and e.Text not like 'DbMgrPartnerCommitPolicy::SetSyncState:%'
--and e.Text not like 'SQL Server blocked access to procedure ''sys.xp_cmdshell'' of component%'
--and e.Text not like 'DbMgrPartnerCommitPolicy::SetSyncAndRecoveryPoint:%'
--and e.Text not like 'Recovery completed for database %'
and e.Text not like 'CHECKDB for database % finished without errors%'
--and e.Text not like 'SQL Server blocked access to procedure%'
--and e.Text not like 'Always On: DebugTraceVarArgs AR %'
--and e.Text not like 'Login failed for user %'
and e.Text not like 'I/O is frozen on database%'
and e.Text not like 'I/O was resumed on database%'
and e.Text not like 'Attempting to load library ''%.dll'' into memory. This is an informational message only. No user action is required.'
--and e.Text not like 'AlwaysOn Availability Groups connection with secondary database terminated for primary database %'
and e.Text not like 'AlwaysOn Availability Groups connection with secondary database established for primary database %'
and e.Text not like 'AlwaysOn Availability Groups connection with primary database established for secondary database %'
and e.Text not like '%is changing roles from "PRIMARY" to "RESOLVING" because the mirroring session or availability group failed over due to role synchronization%'
and e.Text not like '%[DbMgrPartnerCommitPolicy::GetReplicaInfoFromAg] DbMgrPartnerCommitPolicy::SetSyncAndRecoveryPoint%'
and e.Text not like 'The recovery LSN % was identified for the database with ID %. This is an informational message only. No user action is required.'
and e.Text not like '%was killed by an ABORT_AFTER_WAIT = BLOCKERS DDL statement on database_id%'
and e.Text not like '%Nonqualified transactions are being rolled back in database%'
and e.Text not like 'SQL Server blocked access to procedure ''sys.xp_cmdshell%'
--and e.Text like '%ALTER DATABASE%'
--and e.Text like '%rejected due to breached'
--group by left(Text,45) order by occurrences desc
order by id desc

--select e.Text,
--	  count(*) as counts
--from #errorlog e
--where e.Text like 'Login failed for user %'
--group by e.Text
--order by counts desc

--select [Text] as ErrMessage, count(*) as counts from #errorlog
--group by [Text];

/*
select Text = ltrim(rtrim(case when e.Text like 'Length specified in network packet payload did not match number of bytes read%'
							then replace(e.Text, 'Length specified in network packet payload did not match number of bytes read; the connection has been closed. Please contact the vendor of the client library. ', '')
							when  e.Text like 'The login packet used to open the connection is structurally invalid%'
							then replace(e.Text, 'The login packet used to open the connection is structurally invalid; the connection has been closed. Please contact the vendor of the client library. ', '')
							else null
							end)),
	  count(*) as counts
from #errorlog e
where e.Text like 'The login packet used to open the connection is structurally invalid%'
or e.Text like 'Length specified in network packet payload did not match number of bytes read%'
group by e.Text
*/

/*
select create_date 
from sys.databases d
where d.name = 'tempdb'

*/