use DBA

-- Find Latency Details
select * from DBA.[dbo].[vw_Repl_Latency_Details];
--	Get Replication Job Status
select * from DistributorServer.DBA.dbo.vw_ReplicationJobs

--	Get current Latency
select * from DBA..vw_Repl_Latency;

select l.publication, 
		QUOTENAME(p.publisher_db) + ' => '+ QUOTENAME(l.subscriber_db) as [Publisher_Db => Subscriber_Db], 
		l.Token_State, l.current_Latency, l.publisher_commit, l.distributor_commit, --l.subscriber_commit,
		l.[last_token_latency (publisher_commit)], sp.lastwaittype, j.job_name as Log_Reader_Agent_Job, 
		j.is_running, j.is_enabled, l.currentTime
from DBA..vw_Repl_Latency_Details as l 
left join DistributorServer.distribution.dbo.MSpublications as p with (nolock)
	on p.publication = l.publication
left join sys.sysprocesses as sp
	on db_name(sp.dbid) = p.publisher_db and sp.program_name like 'Repl-LogReader%' 
left join DistributorServer.DBA.dbo.vw_ReplicationJobs as j
	on j.category_name = 'REPL-LogReader' and j.publisher_db = p.publisher_db

--	Replication History for Time Range
select * from DBA..[Repl_TracerToken_History] h
where h.publisher_commit >= '2020-02-07 00:00:00.000'
and h.publisher_commit <= '2020-02-07 16:00:00.000'
order by publisher_commit asc, publication asc;

--	Get current Latency
select * from DBA..vw_Repl_Latency;

if(select count(*) as counts from DBA.dbo.vw_Repl_Latency where Latest_Latency >= 60) >= 5
begin
	exec xp_cmdshell 'logman start SQLDBA -S ServerName01' -- \\ServerName01\J$\PerfMon
	exec xp_cmdshell 'logman start SQLDBA -S ServerName02' -- \\ServerName02\Q$\PerfMon
end

select * from DBA..[Repl_TracerToken_Header] where is_processed = 0
select top 1000 * from distribution.dbo.MSdistribution_history h

-- On Distributor:-
-- It will show the latency in Sec
Select object_name, counter_name, instance_name, round(cntr_value/1000,0) as latency_sec 
from sys.dm_os_performance_counters 
where object_name like '%Replica%' and counter_name like '%Logreader:%latency%'
 union
Select object_name, counter_name, instance_name, round(cntr_value/1000,0) as latency_sec 
from sys.dm_os_performance_counters 
where object_name like '%Replica%' and counter_name like '%Dist%latency%'


/*
The replication agent has not logged a progress message in 10 minutes. This might indicate an unresponsive agent or high system activity. Verify that records are being replicated to the destination and that connections to the Subscriber, Publisher, and Distributor are still active.
*/

https://stackoverflow.com/a/45965260/4449743


https://repltalk.com/2010/03/11/divide-and-conquer-transactional-replication-using-tracer-tokens/


https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-repltrans-transact-sql?view=sql-server-ver15
--	All the transactions in the publication database transaction log that are marked for replication but have not been marked as distributed
use DBA
exec sp_repltrans  

--	Commands for transactions marked for replication
use DBA
exec sp_replshowcmds

--	How to enable replication agents for logging to output files in SQL Server
	--	https://support.microsoft.com/en-us/help/312292/how-to-enable-replication-agents-for-logging-to-output-files-in-sql-se
-Output C:\Temp\Facebook_2014_OUTPUT.txt -Outputverboselevel 2

--	0 = Error messages only
--	1 = All Progress
--	2 = Error + Progress


--	http://sqlask.blogspot.com/2017/05/important-commands-and-script-of.html


-- To get Distribution Agent performance and history its status and time and latency and many important details
USE distribution
go
SELECT TOP 100 
		time,
		a.publication,
		a.name as job_name,
		Cast(comments AS XML) AS comments,
		runstatus,
		duration,
		xact_seqno,
		delivered_commands,
		average_commands,
		current_delivery_rate,
		delivered_transactions,
		error_id,
		delivery_latency
		--,a.name
		--,a.publisher_db
		--,a.publication
		--,a.subscriber_db
FROM msdistribution_history as dh --WITH (nolock)
join dbo.MSdistribution_agents as a
on a.id = dh.agent_id
--where a.publication = 'Facebook_2014'
ORDER BY time DESC

--select * from dbo.MSdistribution_agents as a

https://www.mssqltips.com/sqlservertip/3598/troubleshooting-transactional-replication-latency-issues-in-sql-server/