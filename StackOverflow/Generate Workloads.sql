Using Stack Overflow Queries to Generate Workloads
	https://www.brentozar.com/archive/2016/08/dell-dba-days-prep-using-stackexchange-queries-generate-workloads/

Scripted Simulation of SQL Server Loads
https://github.com/gavdraper/ChaosLoad

What is the best way to auto-generate INSERT statements for a SQL Server table?
	https://stackoverflow.com/questions/982568/what-is-the-best-way-to-auto-generate-insert-statements-for-a-sql-server-table


SELECT p.*
FROM dbo.Users as u
join dbo.Posts as p
on u.Id = p.OwnerUserId
where DisplayName = @DisplayName
order by ViewCount;

/*
SELECT TOP (1) DisplayName FROM dbo.Users --where Id in (1,4449743,26837,545629,61305,440595,4197,17174) 
ORDER BY NEWID();
*/


-- Grafana Load
declare @p_start_time datetime2;
declare @p_end_time datetime2;

select @p_start_time = @start_time, @p_end_time = @end_time;

SELECT l2u.utc_time as time, instance_name + '\ --- ' + counter_name as instance_name, CAST(cntr_value AS FLOAT) as cntr_value
FROM (
	select pc.collection_time, pc.instance_name, counter_name, cntr_value
	from dbo.dm_os_performance_counters_nonsql as pc
	where ( collection_time BETWEEN @p_start_time AND @p_end_time )
		and pc.[object_name] = 'LogicalDisk'
		and counter_name in ('Avg. Disk sec/Read','Avg. Disk sec/Write')
		and ( instance_name <> '_Total' and instance_name not like 'HarddiskVolume%' )
	--
	union all
	--
	select pc.collection_time, pc.instance_name, counter_name, cntr_value
	from dbo.dm_os_performance_counters_nonsql_aggregated as pc
	where ( collection_time BETWEEN @p_start_time AND @p_end_time )
		and pc.[object_name] = 'LogicalDisk'
		and counter_name in ('Avg. Disk sec/Read','Avg. Disk sec/Write')
		and ( instance_name <> '_Total' and instance_name not like 'HarddiskVolume%' )
) AS data
cross apply dbo.local2utc(collection_time) as l2u
order by collection_time;

select top 1 collection_time, DATEADD(MINUTE, ABS(CHECKSUM(NEWID()))%20160, collection_time)
from dm_os_performance_counters_nonsql
order by NEWID()