--	https://www.sqlskills.com/blogs/jonathan/identifying-external-memory-pressure-with-dm_os_ring_buffers-and-ring_buffer_resource_monitor/
--exec sp_WhatIsRunning 2
use DBA;
go

alter procedure usp_collect_performance_metrics @verbose bit = 0
as
begin
	set nocount on;

	declare @current_time datetime2 = getdate();
	--select * from sys.dm_os_sys_info

	insert dbo.dm_os_sys_memory
	select --'sys.dm_os_sys_memory' as RunningQuery, 
			@current_time as  collection_time, cast(sm.total_physical_memory_kb * 1.0 / 1024 / 1024 as numeric(20,0)) as total_physical_memory_gb, 
			cast(sm.available_physical_memory_kb * 1.0 / 1024 / 1024 as numeric(20,2)) as available_physical_memory_gb, 
			cast((sm.total_page_file_kb - sm.available_page_file_kb) * 1.0 / 1024 / 1024 as numeric(20,0)) as used_page_file_gb,
			cast(sm.system_cache_kb * 1.0 / 1024 /1024 as numeric(20,2)) as system_cache_gb, 
			cast((sm.available_physical_memory_kb - sm.system_cache_kb) * 1.0 / 1024 as numeric(20,2)) as free_memory_mb,
			sm.system_memory_state_desc,
			cast(((sm.total_physical_memory_kb-sm.available_physical_memory_kb) * 100.0) / sm.total_physical_memory_kb as numeric(20,2)) as memory_usage_percentage
	--into dbo.dm_os_sys_memory
	from sys.dm_os_sys_memory as sm

	-- SQL Server Process Address space info  (Query 6) (Process Memory)
	-- (shows whether locked pages is enabled, among other things)
	INSERT dbo.dm_os_process_memory
	SELECT --'sys.dm_os_process_memory' as RunningQuery, 
			@current_time as  collection_time,
			physical_memory_in_use_kb/1024 AS [SQL Server Memory Usage (MB)],
		   page_fault_count, memory_utilization_percentage, available_commit_limit_kb, 
		   process_physical_memory_low, process_virtual_memory_low,
		   locked_page_allocations_kb/1024 AS [SQL Server Locked Pages Allocation (MB)],
		   large_page_allocations_kb/1024 AS [SQL Server Large Pages Allocation (MB)]
	--into dbo.dm_os_process_memory
	FROM sys.dm_os_process_memory WITH (NOLOCK) OPTION (RECOMPILE);

	--Total amount of RAM consumed by database data (Buffer Pool). This should be the highest usage of Memory on the server.
	insert dbo.dm_os_performance_counters
	Select  --'performance_counters' as RunningQuery,
			@current_time as  collection_time,
			buffer_pool_mb = (Select SUM(pages_kb)/1024 AS [SPA Mem, Mb] FROM sys.dm_os_memory_clerks WITH (NOLOCK) Where type = 'MEMORYCLERK_SQLBUFFERPOOL')
		   --Total amount of RAM used by SQL Server memory clerks (includes Buffer Pool)
		   , all_memory_clerks_mb = (Select SUM(pages_kb)/1024 AS [SPA Mem, Mb] FROM sys.dm_os_memory_clerks WITH (NOLOCK))
		   --How long in seconds since data was removed from the Buffer Pool, to be replaced with data from disk. (Key indicator of memory pressure when below 300 consistently)
		   ,page_life_expectancy = (SELECT cntr_value FROM sys.dm_os_performance_counters WITH (NOLOCK) WHERE [object_name] LIKE N'%Buffer Manager%' AND counter_name = N'Page life expectancy' )
		   --How many memory operations are Pending (should always be 0, anything above 0 for extended periods of time is a very high sign of memory pressure)
		   ,memory_grants_pending = (SELECT cntr_value FROM sys.dm_os_performance_counters WITH (NOLOCK) WHERE [object_name] LIKE N'%Memory Manager%' AND counter_name = N'Memory Grants Pending' )
		   --How many memory operations are Outstanding (should always be 0, anything above 0 for extended periods of time is a very high sign of memory pressure)
		   ,memory_grants_outstanding = (SELECT cntr_value FROM sys.dm_os_performance_counters WITH (NOLOCK) WHERE [object_name] LIKE N'%Memory Manager%' AND counter_name = N'Memory Grants Outstanding' )
		   ,total_server_memory_mb = CAST((SELECT cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'Total Server Memory (KB)' )*1.0/1024 AS decimal(20,0))
		   ,target_server_memory_mb = CAST((SELECT cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'Target Server Memory (KB)' )*1.0/1024 AS decimal(20,0))
	--into dbo.dm_os_performance_counters


	insert dbo.dm_os_ring_buffers
	SELECT	top 1 EventTime as collection_time,  
			CASE WHEN system_cpu_utilization_post_sp2 IS NOT NULL THEN system_cpu_utilization_post_sp2 ELSE system_cpu_utilization_pre_sp2 END AS system_cpu_utilization,  
			CASE WHEN sql_cpu_utilization_post_sp2 IS NOT NULL THEN sql_cpu_utilization_post_sp2 ELSE sql_cpu_utilization_pre_sp2 END AS sql_cpu_utilization 
	--into dbo.dm_os_ring_buffers
	FROM  (	SELECT	record.value('(Record/@id)[1]', 'int') AS record_id,
					DATEADD (ms, -1 * (ts_now - [timestamp]), GETDATE()) AS EventTime,
					100-record.value('(Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS system_cpu_utilization_post_sp2, 
					record.value('(Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS sql_cpu_utilization_post_sp2,
					100-record.value('(Record/SchedluerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS system_cpu_utilization_pre_sp2,
					record.value('(Record/SchedluerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS sql_cpu_utilization_pre_sp2
			FROM (	SELECT	timestamp, CONVERT (xml, record) AS record, cpu_ticks / (cpu_ticks/ms_ticks) as ts_now
					FROM sys.dm_os_ring_buffers cross apply sys.dm_os_sys_info
					WHERE ring_buffer_type = 'RING_BUFFER_SCHEDULER_MONITOR'
					AND record LIKE '%<SystemHealth>%'
				 ) AS t 
		  ) AS t
	ORDER BY EventTime desc;
end
go
