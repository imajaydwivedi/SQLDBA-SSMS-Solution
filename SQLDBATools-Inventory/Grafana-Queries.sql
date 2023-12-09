USE DBA
GO
-- collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
-- master.dbo.local2utc(collection_time) as time

SELECT /* Grafana => PLE */ top 1 page_life_expectancy FROM DBA.dbo.dm_os_performance_counters ORDER BY collection_time desc;

SELECT /* Grafana => PLE Against Time */
  master.dbo.local2utc(collection_time) as time,
  page_life_expectancy
FROM
  DBA.dbo.dm_os_performance_counters
WHERE 
  collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
ORDER BY
  time;

select /* Grafana => CPU Against Time */
		master.dbo.local2utc(collection_time) as time,
		system_cpu_utilization as OS,
		sql_cpu_utilization as [SqlServer]
from DBA..dm_os_ring_buffers
--where collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
order by time asc;

select top 1 master.dbo.local2utc(collection_time) as time,	system_cpu_utilization as CPU from DBA..dm_os_ring_buffers order by time DESC


select top 1 collection_time, cast(available_physical_memory_gb*1024 as decimal(20,0)) as available_physical_memory from [dbo].[dm_os_sys_memory] order by collection_time desc
select top 1 collection_time as time,
		available_physical_memory = case when available_physical_memory_gb >= 1.0 then cast(
from DBA.[dbo].[dm_os_sys_memory] order by collection_time desc

select top 1 collection_time as time, cast(([SQL Server Memory Usage (MB)]*1.0)/1024 as decimal(20,2)) as SqlServer_Physical_Memory_GB from DBA.[dbo].[dm_os_process_memory] order by collection_time desc
select top 1 collection_time as time, cast((page_fault_count*8.0)/1024/1024 as decimal(20,2)) as page_fault_gb from DBA.[dbo].[dm_os_process_memory] order by collection_time desc

select top 1 collection_time as time, cast((total_server_memory_mb*100.0)/target_server_memory_mb as decimal(20,0)) as sql_server_memory_utilization from DBA.[dbo].[dm_os_performance_counters] order by collection_time desc

select cast([collection_time] as smalldatetime) as [time],[dd hh:mm:ss.mss],[login_name],[wait_info],CAST(REPLACE([CPU],',','') AS BIGINT) as [CPU],CAST(REPLACE([reads],',','') AS BIGINT) as reads,CAST(REPLACE([writes],',','') AS BIGINT) as [writes],CAST(REPLACE([used_memory],',','') AS BIGINT) as [used_memory],[host_name],[database_name],[program_name],[sql_command]
from DBA.dbo.WhoIsActive_ResultSets
--where collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
order by [time] desc, [TimeInMinutes] desc


;with t_active_results as 
(	select collection_time, count(*) as active_requests 
	from DBA.dbo.WhoIsActive_ResultSets
	where collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
	group by collection_time
)
select master.dbo.local2utc(collection_time) as [time], active_requests 
from t_active_results 


;WITH T_Active_Requests AS
(
--	Query to find what's is running on server
SELECT	s.session_id
FROM	sys.dm_exec_sessions AS s
LEFT JOIN sys.dm_exec_requests AS r ON r.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) AS bqp
OUTER APPLY sys.dm_exec_text_query_plan(r.plan_handle,r.statement_start_offset, r.statement_end_offset) as sqp
WHERE	s.session_id != @@SPID
	AND (	(CASE	WHEN	s.session_id IN (select ri.blocking_session_id from sys.dm_exec_requests as ri )
					--	Get sessions involved in blocking (including system sessions)
					THEN	1
					ELSE	0
			END) = 1
			OR
			(CASE	WHEN	s.session_id > 50
							AND r.session_id IS NOT NULL -- either some part of session has active request
							AND ISNULL(open_resultset_count,0) > 0 -- some result is open
							AND NOT (s.status = 'sleeping' AND r.status IN ('background','sleeping'))
					THEN	1
					ELSE	0
			END) = 1
			OR
			(CASE	WHEN	s.session_id > 50
							AND ISNULL(r.open_transaction_count,0) > 0
					THEN	1
					ELSE	0
			END) = 1
		)		
)
SELECT SYSUTCDATETIME() as time, COUNT(*) as Counts
FROM T_Active_Requests




;with t_page_faults as
(
	select collection_time, page_fault_count, LAG(page_fault_count) OVER ( ORDER BY collection_time ) as page_fault_count__prev
			,LAG(collection_time) OVER ( ORDER BY collection_time ) as collection_time_prev			
	from DBA.[dbo].[dm_os_process_memory] 
	--where collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
)
select	collection_time, page_fault_count, DATEDIFF(second,collection_time_prev,collection_time) as interval_seconds,
		page_faults_in_interval =
		(case when page_fault_count__prev is null then 0
			 when page_fault_count < page_fault_count__prev then page_fault_count
			 when page_fault_count >= page_fault_count__prev then page_fault_count-page_fault_count__prev
			 else null
			 end)
from t_page_faults
order by collection_time asc

-- ================================================================================================

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET QUOTED_IDENTIFIER OFF
DECLARE @sql varchar(max) = "
SELECT /* Grafana => PLE */ top 1 collection_time as time, cntr_value as page_life_expectancy
FROM dbo.dm_os_performance_counters
WHERE object_name = 'SQLServer:Buffer Manager' and counter_name = 'Page life expectancy'
ORDER BY collection_time desc;
"
SET QUOTED_IDENTIFIER ON
IF ('$server' = SERVERPROPERTY('ServerName'))
BEGIN
  EXEC (@sql);
END;
ELSE
BEGIN
  EXEC (@sql) AT [$server];
END;

-- ================================================================================================

select master.dbo.local2utc(collection_time) as time, counter_name, cntr_value
from DBA.dbo.dm_os_performance_counters as pc
where 1 = 1
and pc.object_name = 'SQLServer:Memory Manager' and counter_name not in ('Memory Grants Pending')
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())


select master.dbo.local2utc(collection_time) as time, counter_name, cntr_value
from DBA.dbo.dm_os_performance_counters as pc
where 1 = 1
and pc.object_name = 'SQLServer:SQL Statistics' --and counter_name not in ('Memory Grants Pending')
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())


select master.dbo.local2utc(collection_time) as time, counter_name, cntr_value
from DBA.dbo.dm_os_performance_counters as pc
where 1 = 1
and pc.object_name = 'SQLServer:Buffer Manager' --and counter_name not in ('Memory Grants Pending')
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())


select distinct object_name, counter_name, instance_name, cntr_type from DBA..dm_os_performance_counters as pc where object_name = 'SQLServer:Buffer Manager'

select * from sys.dm_os_performance_counters as pc 
where --object_name like 'SQLServer:Buffer Manager%'
pc.counter_name like '%available%'
--or pc.counter_name like 'SQL Compilations/sec%'
--or pc.counter_name like 'SQL Re-Compilations/sec%'
/*
SQL Attention rate
SQL Compilations/sec
SQL Re-Compilations/sec
*/

select master.dbo.local2utc(collection_time) as time, cast(free_memory_kb/1024 as decimal(20,2)) as [Available Mbytes], used_page_file_mb = cast(used_page_file_kb*1024 as decimal(30,2))
from DBA.[dbo].[dm_os_sys_memory]
where 1 = 1
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
--and server_name = $server_name
order by time asc


select rtrim(object_name) as object_name, rtrim(counter_name) as counter_name, rtrim(instance_name) as instance_name, rtrim(cntr_type) as cntr_type
from sys.dm_os_performance_counters as pc
where rtrim(object_name) like 'SQLServer:Transactions%'
--
EXCEPT
--
select distinct rtrim(object_name) as object_name, rtrim(counter_name) as counter_name, rtrim(instance_name) as instance_name, rtrim(cntr_type) as cntr_type
from DBA..dm_os_performance_counters as pc
where rtrim(object_name) like 'SQLServer:Transactions'

;with t_counters as (
	select distinct top 100 rtrim(object_name) as object_name, rtrim(counter_name) as counter_name, rtrim(cntr_type) as cntr_type
	from sys.dm_os_performance_counters
	where	(	object_name like 'SQLServer:Transactions%'
			and
				( counter_name like 'Free Space in tempdb (KB)%'
				  or
				  counter_name like 'Longest Transaction Running Time%'
				  or
				  counter_name like 'Transactions%'
				  or
				  counter_name like 'Version Store Size (KB)%'
				)
			)
	order by cntr_type, object_name, counter_name
)
select		--*,
		'			or
			( [object_name] like '''+object_name+'%'' and [counter_name] like '''+counter_name+'%'' )'
from t_counters
--where cntr_type = '272696576'
order by cntr_type, object_name, counter_name


select distinct object_name, counter_name, instance_name
from dbo.dm_os_performance_counters
order by object_name, counter_name, instance_name


SELECT --TOP(5)
		--@current_time as collection_time,
		[type] AS memory_clerk,
		SUM(pages_kb) / 1024 AS size_mb
--INTO DBA..dm_os_memory_clerks
FROM sys.dm_os_memory_clerks WITH (NOLOCK)
GROUP BY [type]
HAVING (SUM(pages_kb) / 1024) > 0
ORDER BY SUM(pages_kb) DESC

SELECT  *
FROM sys.dm_os_memory_cache_counters
order by pages_kb DESC

SELECT objtype, cacheobjtype, 
  AVG(usecounts) AS Avg_UseCount, 
  SUM(refcounts) AS AllRefObjects, 
  SUM(CAST(size_in_bytes AS bigint))/1024/1024 AS Size_MB
FROM sys.dm_exec_cached_plans
--WHERE objtype = 'Adhoc' AND usecounts = 1
GROUP BY objtype, cacheobjtype;

-- ====================================================================================================

select top 1 collection_time as time
        ,available_physical_memory_gb*1024 as decimal(20,0)) as available_physical_memory 
from DBA.[dbo].[dm_os_sys_memory]
order by collection_time desc

-- ====================================================================================================
DECLARE @server_name varchar(256);
set @server_name = 'MSI';

select collection_time as time, (available_physical_memory_kb*1.0)/1024 as [Available Memory]
from DBA.[dbo].[dm_os_sys_memory]
where 1 = 1
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
--and pc.server_name = @server_name
order by collection_time desc

-- ====================================================================================================

select *
from DBA..WhoIsActive_ResultSets as r
where r.collection_time >= '2020-08-23 16:30:00'

-- ====================================================================================================

DECLARE @server_name varchar(256);
set @server_name = 'MSI';

select master.dbo.local2utc(pc.collection_time) as time, pc.cntr_value as [Available MBytes]
from DBA.dbo.dm_os_performance_counters_nonsql as pc
where 1 = 1
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
and pc.server_name = @server_name
and pc.[object_name] = 'Memory'
and pc.counter_name = 'Available MBytes'

-- ====================================================================================================

DECLARE @server_name varchar(256);
set @server_name = 'MSI';

select master.dbo.local2utc(pc.collection_time) as time, pc.counter_name, CEILING(pc.cntr_value) as cntr_value
from DBA.dbo.dm_os_performance_counters_nonsql as pc
where 1 = 1
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
and pc.server_name = @server_name
and pc.[object_name] = 'Memory'
and pc.counter_name in ('Pages Input/Sec','Pages/Sec')

-- ====================================================================================================

DECLARE @server_name varchar(256);
set @server_name = 'MSI';

select master.dbo.local2utc(pc.collection_time) as time, pc.counter_name, CEILING(pc.cntr_value) as cntr_value
from DBA.dbo.dm_os_performance_counters_nonsql as pc
where 1 = 1
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
and pc.server_name = @server_name
and pc.[object_name] = 'Paging File'
and pc.counter_name in ('% Usage','% Usage Peak')


select top 1 collection_time as time, (available_physical_memory_kb*1.0)/1024 as [Available Memory]
from DBA.[dbo].[dm_os_sys_memory]
order by collection_time desc

-- ====================================================================================================

DECLARE @server_name varchar(256);
set @server_name = 'MSI';

select master.dbo.local2utc(pc.collection_time) as time, pc.instance_name + '\ --- ' + pc.counter_name as instance_name, CAST(pc.cntr_value AS FLOAT) as cntr_value
from DBA.dbo.dm_os_performance_counters_nonsql as pc
where 1 = 1
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
and collection_time >= DATEADD(hour,-2,getdate())
and pc.server_name = @server_name
and pc.[object_name] = 'LogicalDisk'
and counter_name in ('Avg. Disk sec/Read','Avg. Disk sec/Write')
and ( instance_name <> '_Total' and instance_name not like 'HarddiskVolume%' )

-- ====================================================================================================

select * from [dbo].[CounterDetails]
where ObjectName = 'Network Interface' 
and CounterName in ('Avg. Disk sec/Read','Avg. Disk sec/Write')

-- ====================================================================================================

DECLARE @server_name varchar(256);
set @server_name = 'MSI';

select --master.dbo.local2utc(pc.collection_time) as time, pc.instance_name + '\ --- ' + pc.counter_name as instance_name, CAST(pc.cntr_value AS FLOAT) as cntr_value
		*
from DBA.dbo.dm_os_performance_counters_nonsql as pc
where 1 = 1
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
and collection_time >= DATEADD(hour,-2,getdate())
and pc.server_name = @server_name
and pc.[object_name] = 'LogicalDisk'
and counter_name in ('Disk Bytes/sec')
and ( instance_name <> '_Total' and instance_name not like 'HarddiskVolume%' )


-- ====================================================================================================

DECLARE @server_name varchar(256);
set @server_name = 'MSI';

select master.dbo.local2utc(pc.collection_time) as time, pc.instance_name --+ '\ --- ' + pc.counter_name as instance_name
		,CAST(pc.cntr_value AS FLOAT) as cntr_value
		--*
from DBA.dbo.dm_os_performance_counters_nonsql as pc
where 1 = 1
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
and collection_time >= DATEADD(hour,-2,getdate())
and pc.server_name = @server_name
and pc.[object_name] = 'Network Interface'
and counter_name in ('Bytes Total/sec')
--and ( instance_name <> '_Total' and instance_name not like 'HarddiskVolume%' )
GO
-- ====================================================================================================

DECLARE @server_name varchar(256);
set @server_name = 'MSI';

select /* Process(sqlservr): %Processor Time */
		master.dbo.local2utc(pc.collection_time) as time
		,metric = case when pc.[object_name] = 'Process' then counter_name + ' ('+pc.instance_name+')'
						when  pc.[object_name] = 'Processor' then counter_name + ' ('+pc.[object_name]+')'
					else null
					end
		,[value] = pc.cntr_value
		--,cpu_count
		--*
from DBA.dbo.dm_os_performance_counters_nonsql as pc with (nolock)
where 1 = 1
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
and collection_time >= DATEADD(MINUTE,-20,getdate())
and pc.server_name = @server_name
and	(	(pc.[object_name] = 'Process' and counter_name like '!% % Time' ESCAPE '!' and pc.instance_name = 'sqlservr')
		or
		(pc.[object_name] = 'Processor' and counter_name like '!% % Time' ESCAPE '!')
	)
--and counter_name like '!% Processor Time' ESCAPE '!'
order by time
GO

-- ====================================================================================================

DECLARE @server_name varchar(256);
set @server_name = 'MSI';

select /* Process(sqlservr): %Processor Time */
		master.dbo.local2utc(pc.collection_time) as time
		,metric = case when pc.counter_name = 'Context Switches/sec' then 'Context Switches per CPU/sec'+' ('+pc.[object_name]+')'
						else pc.counter_name+' ('+pc.[object_name]+')'
						end
		,[value] = case when pc.counter_name = 'Context Switches/sec' then pc.cntr_value/si.cpu_count
						else pc.cntr_value
						end
		--,cpu_count
		--*
from DBA.dbo.dm_os_performance_counters_nonsql as pc with (nolock)
outer apply ( select top 1 cpu_count from DBA.dbo.dm_os_sys_info as si where si.collection_time <= pc.collection_time) as si
where 1 = 1
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
and collection_time >= DATEADD(MINUTE,-20,getdate())
and pc.server_name = @server_name
and	(	(pc.[object_name] = 'System' and counter_name = 'Processor Queue Length')
		or
		(pc.[object_name] = 'System' and counter_name = 'Context Switches/sec')
	)
--and counter_name like '!% Processor Time' ESCAPE '!'
order by time
GO

-- ====================================================================================================
declare @server varchar(256)
set @server = '$server';

select	time = master.dbo.local2utc(pc.collection_time),
		metric = pc.counter_name,
		[value] = pc.cntr_value
from DBA.dbo.dm_os_performance_counters as pc
where 1 = 1
--and server_name = @server
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
and (	pc.[object_name] = 'SQLServer:Memory Manager' and pc.counter_name in ('Memory Grants Outstanding','Memory Grants Pending')	)
order by pc.collection_time

-- ====================================================================================================
declare @server varchar(256)
set @server = '$server';

select  /* Load on Disk */
		[time] = master.dbo.local2utc(pc.collection_time),
		metric = counter_name+' ('+pc.instance_name+')',
		[value] = pc.cntr_value
		--distinct object_name, counter_name --,instance_name
from DBA.dbo.dm_os_performance_counters_nonsql as pc
where 1 = 1
--and server_name = @server
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
and pc.[object_name] in ( 'Network Interface' )
and pc.counter_name in ('Bytes Total/sec')
--and pc.counter_name in ('% Disk Time','% Idle Time','% Disk Read Time','% Disk Write Time')
and pc.counter_name in ('Disk Bytes/sec','Disk Write Bytes/sec','Disk Read Bytes/sec')
--and pc.counter_name in ('Avg. Disk sec/Read','Avg. Disk sec/Write')
and NOT (pc.instance_name = '_Total' or pc.instance_name like 'Harddisk%')
order by pc.collection_time

-- ====================================================================================================
;WITH T_Dbs AS (
	select *
	from DBA.dbo.dm_os_performance_counters as pc
	where 1 = 1
	--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
	and pc.[object_name] = 'SQLServer:Databases'
	and pc.counter_name in ('Log File(s) Used Size (KB)','Log File(s) Size (KB)')
	--and pc.counter_name = 'Percent Log Used'
	and instance_name not in ('_Total','master','model','mssqlsystemresource')
	--and pc.cntr_value/(1024.0*1024) > 1.0
)
select [time] = master.dbo.local2utc(pc.collection_time),
		--pc.collection_time,
		metric = case when counter_name = 'Log File(s) Size (KB)' then 'Total Size (KB) - '+QUOTENAME(pc.instance_name)
						when counter_name = 'Log File(s) Used Size (KB)' then 'Used Size (KB) - '+QUOTENAME(pc.instance_name)
						else counter_name+' ('+pc.instance_name+')'
						end ,
		[value] = pc.cntr_value
from T_Dbs as pc
where pc.instance_name in (	select i.instance_name 
							from T_Dbs as i 
							where i.counter_name = 'Log File(s) Size (KB)'
								and i.cntr_value/(1024.0*1024) > 1.0
						)
order by collection_time

-- ====================================================================================================

select --master.dbo.local2utc(collection_time) as time, instance_name as metric, cntr_value as [value]
		distinct pc.object_name, pc.counter_name, pc.instance_name, pc.cntr_type
from DBA.dbo.dm_os_performance_counters as pc
where 1 = 1
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
and pc.collection_time >= GETDATE()-1
and (	pc.object_name = 'SQLServer:General Statistics'
		and	
		(	pc.counter_name in ('User Connections','Logins/sec','Logouts/sec') )
	)
order by pc.collection_time


select --master.dbo.local2utc(collection_time) as time, instance_name as metric, cntr_value as [value]
		distinct pc.object_name, pc.counter_name, pc.instance_name, pc.cntr_type
from DBA.dbo.dm_os_performance_counters as pc
where 1 = 1
--and collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
and pc.collection_time >= GETDATE()-1
and pc.object_name like 'SQLServer:Transactions'
order by pc.collection_time



select *
from sys.dm_os_performance_counters as pc
where pc.counter_name like '%table%'
