/*	Troubleshooting tempdb growth due to Version Store usage
	https://blogs.msdn.microsoft.com/sqlserverfaq/2010/10/13/troubleshooting-tempdb-growth-due-to-version-store-usage/
*/

--select * from sys.dm_os_performance_counters pc	where rtrim(pc.counter_name) in ('Version Cleanup rate (KB/s)');

--select 'sys.dm_tran_version_store' as DMV, DB_NAME(database_id) as dbName, count(*) as counts from sys.dm_tran_version_store group by DB_NAME(database_id);

--	Find session details with active transaction in Version Store
select * from DBA..WhoIsActive_ResultSets r where r.collection_time = (select max(ri.collection_time) from DBA..WhoIsActive_ResultSets ri)
	and r.session_id in (select v.session_id from sys.dm_tran_active_snapshot_database_transactions v);

--	Find all the transactions currently maintaining an active version store 
select	GETDATE() AS collection_time, (a.elapsed_time_seconds/60) as elapsed_time_minutes, a.*,b.kpid,b.blocked,b.lastwaittype,b.waitresource,db_name(b.dbid) as database_name,
		b.cpu,b.physical_io,b.memusage,b.login_time,b.last_batch,b.open_tran,b.status,b.hostname,
		CASE LEFT(b.program_name,15)
            WHEN 'SQLAgent - TSQL' THEN 
            (     select top 1 'SQL Job = '+j.name from msdb.dbo.sysjobs (nolock) j
                  inner join msdb.dbo.sysjobsteps (nolock) s on j.job_id=s.job_id
                  where right(cast(s.job_id as nvarchar(50)),10) = RIGHT(substring(b.program_name,30,34),10) )
            WHEN 'SQL Server Prof' THEN 'SQL Server Profiler'
            ELSE b.program_name
            END as Program_name,
		b.cmd,b.loginame,request_id
from sys.dm_tran_active_snapshot_database_transactions a inner join sys.sysprocesses b on a.session_id = b.spid
where open_tran <> 0
AND (a.elapsed_time_seconds/60) >= 180
order by elapsed_time_minutes desc;



--dbcc inputbuffer(234)
--kill 210