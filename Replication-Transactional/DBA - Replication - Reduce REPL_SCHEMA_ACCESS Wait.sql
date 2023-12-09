--	use DBA

EXEC DBA.dbo.usp_RemoveReplSchemaAccessContention @verbose = 1, @LogToTable = 0,  @Job_Execution_Threshold_Minutes = 20
GO

/*
select l.publication, 
		case when p.publisher_db = l.subscriber_db then quotename(p.publisher_db) else QUOTENAME(p.publisher_db) + ' => '+ QUOTENAME(l.subscriber_db) end as [Publisher_Db => Subscriber_Db], 
		l.Token_State, l.current_Latency, l.publisher_commit, l.distributor_commit, --l.subscriber_commit,
		l.[last_token_latency (publisher_commit)], sp.lastwaittype, j.job_name as Log_Reader_Agent_Job, 
		j.is_running --,l.currentTime
		,sp.blocked
from DBA..vw_Repl_Latency_Details as l 
left join DistributorServer.distribution.dbo.MSpublications as p with (nolock)
	on p.publication = l.publication
left join sys.sysprocesses as sp
	on db_name(sp.dbid) = p.publisher_db and sp.program_name like 'Repl-LogReader%' 
left join DistributorServer.DBA.dbo.vw_ReplicationJobs as j
	on j.category_name = 'REPL-LogReader' and j.publisher_db = p.publisher_db  

exec sp_WhoIsActive @filter = '221'

select getdate() as currentTime, * from DistributorServer.DBA.dbo.JobRunningStateChangeLog l 
where l.collectionTime >= dateadd(minute,-90,getdate()) 
--and Source = 'usp_RemoveReplSchemaAccessContention' 
order by collectionTime desc;

--exec DistributorServer.DBA.dbo.usp_ChangeJobRunningState @jobs = 'Replication-LogReader-Agent-LogName'
--									,@state = 'Start', @verbose = 1
--									,@LogToTable = 1, @Source = 'Manual - Ajay';
*/

/*
declare @starttime datetime2 = getdate();
declare @collectiontime smalldatetime;

--	Get oldest entry within last 2 hour
select @collectiontime = min([Current Time]) 
from dbo.repl_schema_access_start_entry s 
where s.[Current Time] >= dateadd(hour,-2,getdate());

-- Continue in loop for 120 minutes
while datediff(MINUTE,@starttime,getdate()) <= 120 and @collectiontime is not null
begin

	select * from dbo.repl_schema_access_Latency with (nolock) 
		where [Current Time] = @collectiontime;
	select * from dbo.repl_schema_access_start_entry with (nolock) 
		where [Current Time] = @collectiontime;
	select * from dbo.repl_schema_access_end_entry with (nolock) 
		where [Current Time] = @collectiontime;

	waitfor delay '00:00:5';

	select @collectiontime = min([Current Time]) 
	from dbo.repl_schema_access_start_entry s 
	where s.[Current Time] > @collectiontime;
end
*/

/*
use DBA
go

--drop table repl_schema_access_Latency
create table dbo.repl_schema_access_Latency 
(
	[publication] [varchar](200) NULL,
	[Publisher_Db => Subscriber_Db] [varchar](520) NULL,
	[Token_State] [varchar](7) NOT NULL,
	[current_Latency] bigint NULL,
	[publisher_commit] [datetime] NULL,
	[distributor_commit] [datetime] NULL,
	[last_token_latency (publisher_commit)] [varchar](150) NULL,
	[lastwaittype] [varchar](100) NULL,
	[Log_Reader_Agent_Job] [varchar](200) NULL,
	[replicated transactions] [bigint] NULL,
	[is_running] [bit] NULL,
	[Current Time] smalldatetime
)
go
create clustered index ci_repl_schema_access_Latency on dbo.repl_schema_access_Latency([Current Time])
go

--drop table repl_schema_access_start_entry
create table dbo.repl_schema_access_start_entry ([CodePortion] char(30), [@is_latency_present] bit, [@is_repl_schema_contention_present] bit, [@is_job_not_runnning] bit, [@JobNames] varchar(2000), [@Job_Execution_Threshold_Minutes] int, [@JobName_lastStarted] varchar(200), [@Job_lastStarted_Time] datetime2, [Current Time] smalldatetime , [Stop/Start Block Logic] char(5))
go

create clustered index ci_repl_schema_access_start_entry on dbo.repl_schema_access_start_entry([Current Time])
go

--drop table repl_schema_access_end_entry
create table dbo.repl_schema_access_end_entry ([CodePortion] varchar(30) null, [Stop-Job-Logic] char(5) null, [Start-Job-Logic (@startJob_bit)] char(5) null, [Is Job Started (@isJobStarted)] char(5) null, [@JobName] varchar(500) null, [Current Time] smalldatetime null)
go
create clustered index ci_repl_schema_access_end_entry on dbo.repl_schema_access_end_entry([Current Time])
go
*/

/*
declare @tsql_KillSession nvarchar(max);

-- Start loop to kill each session one by one
while exists (select * from DistributorServer.master.sys.sysprocesses as sp 
				where sp.spid > 50 and sp.program_name = 'Microsoft SQL Server' 
				and sp.lastwaittype = 'LCK_M_S' and hostname = 'YourPublisherServerName' and cmd = 'SELECT'
				and sp.loginame in ('Contso\adwivedi','Contso\sqlagent')
		)
begin
	set @tsql_KillSession = '';
	set @tsql_KillSession = (
								select top 1 'kill ' + cast(spid as varchar(20)) + ';
								' 
								from DistributorServer.master.sys.sysprocesses as sp 
								where sp.spid > 50 and sp.program_name = 'Microsoft SQL Server' 
								and sp.lastwaittype = 'LCK_M_S' and hostname = 'YourPublisherServerName' and cmd = 'SELECT'
								and sp.loginame in ('Contso\adwivedi','Contso\sqlagent')
							);

	begin try
		EXEC (@tsql_KillSession) AT DistributorServer;
		--print @tsql_KillSession
		--break;
	end try
	begin catch
		print 'Error occurred while executing below query:- '+char(10)+char(13)+@tsql_KillSession;
	end catch
end
*/

/*
set nocount on;

declare @tsql_KillSession nvarchar(max);
declare @job_name nvarchar(2000);
declare @verbose bit = 1;
declare @waittime_threshold bigint = 0 --300000;

if @verbose = 1
	print 'Start loop if there are blocked sessions to be released';
-- Start loop to kill each session one by one
while exists (select * from DistributorServer.master.sys.sysprocesses as sp 
				where sp.spid > 50 and sp.program_name = 'Microsoft SQL Server' 
				and sp.lastwaittype = 'LCK_M_S' and hostname = 'YourPublisherServerName' and cmd = 'SELECT'
				and sp.loginame in ('Contso\adwivedi','Contso\sqlagent')
		)
begin
	if OBJECT_ID('tempdb..#blocking') is not null
		drop table #blocking;
	set @tsql_KillSession = '';
	set @job_name = null;

	if @verbose = 1
		print 'Creating table #blocking'
	;with cte_blocked as
	(	select sp.spid, sp.blocked, sp.lastwaittype, sp.waittime, sp.waitresource, 
			sp.open_tran, sp.status, sp.hostname, sp.program_name, sp.cmd, sp.loginame, db_name(dbid) as dbname
		from DistributorServer.master.sys.sysprocesses as sp
		where sp.spid > 50 and sp.program_name = 'Microsoft SQL Server' 
		and sp.lastwaittype = 'LCK_M_S' and hostname = 'YourPublisherServerName' and cmd = 'SELECT'
		and sp.loginame in ('Contso\adwivedi','Contso\sqlagent')
		--
		union all
		--
		select	b.spid, b.blocked, b.lastwaittype, b.waittime, b.waitresource, 
			b.open_tran, b.status, b.hostname, b.program_name, b.cmd, b.loginame, db_name(b.dbid) as dbname
		from	cte_blocked as p
		inner join DistributorServer.master.sys.sysprocesses as b
		on b.spid = p.blocked
	)
	select	spid, blocked, lastwaittype, waittime, waitresource,open_tran, status, hostname, cmd, loginame, dbname
			,[program_name] = CASE	WHEN	program_name like 'SQLAgent - TSQL JobStep %'
				THEN	(	select	top 1 'SQL Job = '+j.name 
							from msdb.dbo.sysjobs (nolock) as j
							inner join msdb.dbo.sysjobsteps (nolock) AS js on j.job_id=js.job_id
							where right(cast(js.job_id as nvarchar(50)),10) = RIGHT(substring(program_name,30,34),10) 
						)
				ELSE	program_name
				END
	into #blocking
	from cte_blocked as p
	order by waittime asc;

	if @verbose = 1
		select '#blocking' as QueryRunning, * from #blocking;

	if @verbose = 1
		print 'Checking if Log Reader agent is blocker'
	-- Stop log reader agent job
	if exists (select * from #blocking b where b.program_name like 'Repl-LogReader%')
	begin
		
		if @verbose = 1
			print 'Finding blocker LogReader agent Job Name..'
		select top 1 @job_name = j.job_name
		--b.*, j.publisher_db, j.publication, j.job_name, j.is_running, j.category_name 
		from #blocking b
		join DistributorServer.DBA.dbo.vw_ReplicationJobs as j
		on b.program_name = ('REPL-LogReader'+'-2-'+j.publisher_db+'-'+cast(db_id(publisher_db) as varchar(5)))
		and j.category_name = 'REPL-LogReader'
		where waittime >= @waittime_threshold
		and not exists (select * from DistributorServer.DBA.dbo.JobRunningStateChangeLog as l 
						where l.CollectionTime >= DATEADD(MINUTE,-15,getdate()) and l.Source = 'usp_RemoveReplSchemaAccessContention'
						and l.JobName = j.job_name
						)

		if @verbose = 1
			print '@job_name = '+QUOTENAME(ISNULL(@job_name,''));

		if @job_name is not null
		begin
			exec DistributorServer.DBA.dbo.usp_ChangeJobRunningState @jobs = @job_name, @state = 'Stop', @verbose = @verbose,
											@LogToTable = 1, @Source = 'DBA - Replication - Repl_Schema_Access - Stop Blocking'
			print 'Job '+quotename(@job_name)+' has been stopped'
		end
	end

	WAITFOR DELAY '00:00:30'
	BREAK
end
*/