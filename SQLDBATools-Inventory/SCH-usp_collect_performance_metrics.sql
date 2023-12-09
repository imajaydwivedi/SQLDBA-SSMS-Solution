USE DBA
GO

create or alter procedure [dbo].[usp_collect_performance_metrics] @verbose bit = 0, @metrics varchar(100) = 'all'
as
begin
	set nocount on;

	declare @current_time datetime2 = SYSDATETIME(); /* removing usage of this due to high Page Splits */
	declare @object_name varchar(255);
	set @object_name = (case when @@SERVICENAME = 'MSSQLSERVER' then 'SQLServer' else 'MSSQL$'+@@SERVICENAME end);

	--select * from sys.dm_os_sys_info

	if @metrics = 'all' or @metrics = 'dm_os_memory_clerks'
	begin
		INSERT INTO dbo.dm_os_memory_clerks
		SELECT --TOP(5)
				@current_time as collection_time,
				[type] AS memory_clerk,
				SUM(pages_kb) / 1024 AS size_mb
		--INTO DBA..dm_os_memory_clerks
		FROM sys.dm_os_memory_clerks WITH (NOLOCK)
		GROUP BY [type]
		HAVING (SUM(pages_kb) / 1024) > 0
		ORDER BY SUM(pages_kb) DESC
	end

	if @metrics = 'all' or @metrics = 'dm_os_sys_memory'
	begin
		insert dbo.dm_os_sys_memory
		 ([collection_time], [server_name], [total_physical_memory_kb], [available_physical_memory_kb], [used_page_file_kb], [system_cache_kb], [free_memory_kb], [system_memory_state_desc])
		select collection_time = SYSDATETIME()
				,[server_name] = @@SERVERNAME
				,[total_physical_memory_kb]
				,[available_physical_memory_kb]
				,[used_page_file_kb] = total_page_file_kb - available_page_file_kb
				,[system_cache_kb]
				,[free_memory_kb] = available_physical_memory_kb - system_cache_kb
				,system_memory_state_desc
		from sys.dm_os_sys_memory as sm;
	end

	-- SQL Server Process Address space info  (Query 6) (Process Memory)
	-- (shows whether locked pages is enabled, among other things)
	if @metrics = 'all' or @metrics = 'dm_os_process_memory'
	begin
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
	end

	
	if @metrics = 'all' or @metrics = 'dm_os_performance_counters'
	begin
		-- https://www.sqlshack.com/troubleshooting-sql-server-issues-sys-dm_os_performance_counters/
		INSERT dbo.dm_os_performance_counters
		SELECT /* -- all performance counters that do not require additional calculation */
				[collection_time] = SYSDATETIME(), server_name = @@SERVERNAME,
				rtrim(object_name) as object_name, rtrim(counter_name) as counter_name, rtrim(instance_name) as instance_name, cntr_value ,cntr_type
				,id = ROW_NUMBER()OVER(ORDER BY SYSDATETIME())
		--into dbo.dm_os_performance_counters
		FROM sys.dm_os_performance_counters as pc
		WHERE cntr_type in ( 65792 /* PERF_COUNTER_LARGE_RAWCOUNT */	)
		  and
		  (	( [object_name] LIKE (@object_name+':Buffer Manager%') AND counter_name like 'Page life expectancy%' )
		    or
			( [object_name] like (@object_name+':Buffer Manager%') and [counter_name] like 'Database pages%' )
			or
			( [object_name] like (@object_name+':Buffer Manager%') and [counter_name] like 'Target pages%' )
			or
			( [object_name] LIKE (@object_name+':Memory Manager%') AND counter_name like 'Memory Grants Pending%' )
			or
			( [object_name] LIKE (@object_name+':Memory Manager%') AND counter_name like 'Granted Workspace Memory (KB)%' )
			or
			( [object_name] LIKE (@object_name+':Memory Manager%') AND counter_name like 'Maximum Workspace Memory (KB)%' )
			or
			( [object_name] LIKE (@object_name+':Memory Manager%') AND counter_name like 'Memory Grants Outstanding%' )
			or
			( [object_name] LIKE (@object_name+':Memory Manager%') AND counter_name like 'Stolen Server Memory (KB)%' )
			or
			( [object_name] LIKE (@object_name+':Memory Manager%') AND counter_name = 'Total Server Memory (KB)' )
			or
			( [object_name] LIKE (@object_name+':Memory Manager%') AND counter_name = 'Target Server Memory (KB)' )
			or
			( [object_name] LIKE (@object_name+':Memory Manager%') AND counter_name = 'SQL Cache Memory (KB)' )
			or
			( [object_name] LIKE (@object_name+':Memory Manager%') AND counter_name = 'Free Memory (KB)' )
			or
			( [object_name] like (@object_name+':Databases%') and [counter_name] like 'Data File(s) Size (KB)%' )
			or
			( [object_name] like (@object_name+':Databases%') and [counter_name] like 'Log File(s) Size (KB)%' )
			or
			( [object_name] like (@object_name+':Databases%') and [counter_name] like 'Log File(s) Used Size (KB)%' )
			or
			( [object_name] like (@object_name+':Databases%') and [counter_name] like 'Log Growths%' )
			or
			( [object_name] like (@object_name+':Databases%') and [counter_name] like 'Log Shrinks%' )
			or
			( [object_name] like (@object_name+':Databases%') and [counter_name] like 'Log Truncations%' )
			or
			( [object_name] like (@object_name+':Databases%') and [counter_name] like 'Percent Log Used%' )
			or
			( [object_name] like (@object_name+':Cursor Manager by Type%') and [counter_name] like 'Active cursors%' )
			or
			( [object_name] like (@object_name+':General Statistics%') and [counter_name] like 'User Connections%' )
			or
			( [object_name] like (@object_name+':Wait Statistics%') )
			or
			( [object_name] like (@object_name+':Transactions%') and [counter_name] like 'Free Space in tempdb (KB)%' )
			or
			( [object_name] like (@object_name+':Transactions%') and [counter_name] like 'Longest Transaction Running Time%' )
			or
			( [object_name] like (@object_name+':Transactions%') and [counter_name] like 'Transactions%' )
			or
			( [object_name] like (@object_name+':Transactions%') and [counter_name] like 'Version Store Size (KB)%' )
		)
		ORDER BY collection_time, server_name, [object_name], counter_name, id;
		
		-- https://www.sqlshack.com/troubleshooting-sql-server-issues-sys-dm_os_performance_counters/
		INSERT dbo.dm_os_performance_counters
		SELECT /* counter that require Fraction & Base */
				SYSDATETIME() as collection_time, 
				server_name = @@SERVERNAME, rtrim(fr.object_name) as object_name, rtrim(fr.counter_name) as counter_name, rtrim(fr.instance_name) as instance_name, cntr_value = case when bs.cntr_value <> 0 then (100*(fr.cntr_value/bs.cntr_value)) else fr.cntr_value end, fr.cntr_type
				,id = ROW_NUMBER()OVER(ORDER BY SYSDATETIME())
		FROM sys.dm_os_performance_counters as fr
		OUTER APPLY
		  (	SELECT * FROM sys.dm_os_performance_counters as bs 
			WHERE bs.cntr_type = 1073939712 /* PERF_LARGE_RAW_BASE  */ 
			 AND bs.[object_name] = fr.[object_name] 
			 AND (	REPLACE(LOWER(RTRIM(bs.counter_name)),' base','') = REPLACE(LOWER(RTRIM(fr.counter_name)),' ratio','')
					OR
					REPLACE(LOWER(RTRIM(bs.counter_name)),' base','') = LOWER(RTRIM(fr.counter_name))
				 )
			 AND bs.instance_name = fr.instance_name
		  ) as bs
		WHERE fr.cntr_type = 537003264 /* PERF_LARGE_RAW_FRACTION */
		  and
		  ( ( fr.[object_name] like (@object_name+':Buffer Manager%') and fr.counter_name like 'Buffer cache hit ratio%' )
			or
			( fr.[object_name] like (@object_name+':Access Methods%') and fr.counter_name like 'Worktables From Cache Ratio%' )
		  )
		ORDER BY collection_time, server_name, [object_name], counter_name, id;;
	end

	if @metrics = 'all' or @metrics = 'dm_os_performance_counters_deprecated_features'
	begin
		INSERT dbo.dm_os_performance_counters
		SELECT /* -- all performance counters that do not require additional calculation */
				[collection_time] = SYSDATETIME(), server_name = @@SERVERNAME,
				rtrim(object_name) as object_name, rtrim(counter_name) as counter_name, rtrim(instance_name) as instance_name, cntr_value ,cntr_type
				,id = ROW_NUMBER()OVER(ORDER BY SYSDATETIME())
		--into dbo.dm_os_performance_counters
		FROM sys.dm_os_performance_counters as pc
		WHERE [object_name] like (@object_name+':Deprecated Features%')
		ORDER BY collection_time, server_name, [object_name], counter_name, id;
	end

	if @metrics = 'all' or @metrics = 'dm_os_performance_counters_sampling'
	begin
		IF OBJECT_ID('tempdb..#dm_os_performance_counters_PERF_AVERAGE_BULK_t1') IS NOT NULL
			DROP TABLE #dm_os_performance_counters_PERF_AVERAGE_BULK_t1;
		SELECT SYSDATETIME() as collection_time, * 
		INTO #dm_os_performance_counters_PERF_AVERAGE_BULK_t1
		FROM sys.dm_os_performance_counters as pc
		WHERE cntr_type in (1073874176 /* PERF_AVERAGE_BULK */
							,1073939712 /* PERF_LARGE_RAW_BASE */
							) --  
		  and
		  ( ( [object_name] like (@object_name+':Locks%') and counter_name like 'Average Wait Time%' )
			or
			( [object_name] like (@object_name+':Latches%') and counter_name like 'Average Latch Wait Time%' )
		  );

		-- Another Query
		-- https://www.sqlshack.com/troubleshooting-sql-server-issues-sys-dm_os_performance_counters/
		IF OBJECT_ID('tempdb..#dm_os_performance_counters_PERF_COUNTER_BULK_COUNT_t1') IS NOT NULL
			DROP TABLE #dm_os_performance_counters_PERF_COUNTER_BULK_COUNT_t1;
		SELECT SYSDATETIME() as collection_time, * 
		INTO #dm_os_performance_counters_PERF_COUNTER_BULK_COUNT_t1
		FROM sys.dm_os_performance_counters as pc
		WHERE cntr_type = 272696576 /* PERF_COUNTER_BULK_COUNT */
		  and
		  ( ( [object_name] like (@object_name+':SQL Statistics%') and counter_name like 'Batch Requests/sec%' )
			or
			( [object_name] like (@object_name+':SQL Statistics%') and counter_name like 'SQL Attention rate%' )
			or
			( [object_name] like (@object_name+':SQL Statistics%') and counter_name like 'SQL Compilations/sec%' )
			or
			( [object_name] like (@object_name+':SQL Statistics%') and counter_name like 'SQL Re-Compilations/sec%' )
			or
			( [object_name] like (@object_name+':SQL Statistics%') and [counter_name] like 'Auto-Param Attempts/sec%' )
			or
			( [object_name] like (@object_name+':SQL Statistics%') and [counter_name] like 'Failed Auto-Params/sec%' )
			or
			( [object_name] like (@object_name+':SQL Statistics%') and [counter_name] like 'Safe Auto-Params/sec%' )
			or
			( [object_name] like (@object_name+':SQL Statistics%') and [counter_name] like 'Unsafe Auto-Params/sec%' )
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Page lookups/sec%')
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Lazy writes/sec%')
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Page reads/sec%')
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Page writes/sec%')
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Logins/sec%')
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Free list stalls/sec%')
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Checkpoint pages/sec%')
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Readahead pages/sec%')
			or
			( [object_name] like (@object_name+':Locks%') and counter_name like 'Number of Deadlocks/sec%' )
			or
			( [object_name] like (@object_name+':Locks%') and counter_name like 'Lock Wait Time (ms)%')
			or
			( [object_name] like (@object_name+':Locks%') and counter_name like 'Lock Waits/sec%')
			or
			( [object_name] like (@object_name+':Latches%') and [counter_name] like 'Latch Waits/sec%' )
			or
			( [object_name] like (@object_name+':Latches%') and [counter_name] like 'Total Latch Wait Time (ms)%' )
			or
			( [object_name] like (@object_name+':Access Methods%') and counter_name like 'Full Scans/sec%')
			or
			( [object_name] like (@object_name+':Access Methods%') and counter_name like 'Forwarded Records/sec%')
			or
			( [object_name] like (@object_name+':Access Methods%') and counter_name like 'Index Searches/sec%')
			or
			( [object_name] like (@object_name+':Access Methods%') and counter_name like 'Page Splits/sec%')
			or
			( [object_name] like (@object_name+':Access Methods%') and counter_name like 'Workfiles Created/sec%')
			or
			( [object_name] like (@object_name+':Access Methods%') and counter_name like 'Worktables Created/sec%')
			or
			( [object_name] like (@object_name+':Access Methods%') and counter_name like 'Table Lock Escalations/sec%')
			or
			( [object_name] like (@object_name+':Databases%') and counter_name like 'Log Bytes Flushed/sec%')
			or
			( [object_name] like (@object_name+':Databases%') and counter_name like 'Log Flush Wait Time%')
			or
			( [object_name] like (@object_name+':Databases%') and counter_name like 'Log Flush Waits/sec%')
			or
			( [object_name] like (@object_name+':Databases%') and counter_name like 'Log Flushes/sec%')
			or
			( [object_name] like (@object_name+':SQL Errors%') and counter_name like 'Errors/sec%')
			or
			( [object_name] like (@object_name+':General Statistics%') and [counter_name] like 'Logins/sec%' )
			or
			( [object_name] like (@object_name+':General Statistics%') and [counter_name] like 'Logouts/sec%' )
		  );

		--
		WAITFOR DELAY '00:00:04'
		--

		IF OBJECT_ID('tempdb..#dm_os_performance_counters_PERF_AVERAGE_BULK_t2') IS NOT NULL
			DROP TABLE #dm_os_performance_counters_PERF_AVERAGE_BULK_t2;
		SELECT SYSDATETIME() as collection_time, * 
		INTO #dm_os_performance_counters_PERF_AVERAGE_BULK_t2
		FROM sys.dm_os_performance_counters as pc
		WHERE cntr_type in (1073874176 /* PERF_AVERAGE_BULK */
							,1073939712 /* PERF_LARGE_RAW_BASE */
							) --  
		  and
		  ( ( [object_name] like (@object_name+':Locks%') and counter_name like 'Average Wait Time%' )
			or
			( [object_name] like (@object_name+':Latches%') and counter_name like 'Average Latch Wait Time%' )
		  );
		WITH Time_Samples AS (
			SELECT t1.collection_time as time1, t2.collection_time as time2,
					t1.object_name, t1.counter_name, t1.instance_name,
					t1.cntr_type as cntr_type_t1, t1.cntr_value as cntr_value_t1,
					t2.cntr_type as cntr_type_t2, t2.cntr_value as cntr_value_t2
			FROM #dm_os_performance_counters_PERF_AVERAGE_BULK_t1 as t1
			join #dm_os_performance_counters_PERF_AVERAGE_BULK_t2 as t2
			  on t1.collection_time < t2.collection_time and 
				 t2.object_name = t1.object_name and t2.counter_name = t1.counter_name and ISNULL(t2.instance_name,'') = ISNULL(t1.instance_name,'')
		)
		INSERT dbo.dm_os_performance_counters
		SELECT [collection_time] = SYSDATETIME(),
				server_name = @@SERVERNAME,
				object_name = rtrim(fr.object_name), 
				counter_name = rtrim(fr.counter_name), 
				instance_name = rtrim(fr.instance_name), 
				cntr_value = case when (bs.cntr_value_t2-bs.cntr_value_t1) <> 0 then (fr.cntr_value_t2-fr.cntr_value_t1)/(bs.cntr_value_t2-bs.cntr_value_t1) else (fr.cntr_value_t2-fr.cntr_value_t1) end
				,cntr_type = fr.cntr_type_t2
				,id = ROW_NUMBER()OVER(ORDER BY SYSDATETIME())
		FROM Time_Samples as fr join Time_Samples as bs 
		on fr.object_name = bs.object_name
			and replace(rtrim(fr.counter_name),' (ms)','') = replace(rtrim(bs.counter_name),' Base','')
			and fr.cntr_type_t2 = '1073874176' and bs.cntr_type_t2 = '1073939712'
		ORDER BY collection_time, server_name, [object_name], counter_name, id;

		-- Another Query
		IF OBJECT_ID('tempdb..#dm_os_performance_counters_PERF_COUNTER_BULK_COUNT_t2') IS NOT NULL
			DROP TABLE #dm_os_performance_counters_PERF_COUNTER_BULK_COUNT_t2;
		SELECT SYSDATETIME() as collection_time, * 
		INTO #dm_os_performance_counters_PERF_COUNTER_BULK_COUNT_t2
		FROM sys.dm_os_performance_counters as pc
		WHERE cntr_type = 272696576 /* PERF_COUNTER_BULK_COUNT */
		  and
		  ( ( [object_name] like (@object_name+':SQL Statistics%') and counter_name like '%Batch Requests/sec%' )
			or
			( [object_name] like (@object_name+':SQL Statistics%') and counter_name like 'SQL Attention rate%' )
			or
			( [object_name] like (@object_name+':SQL Statistics%') and counter_name like 'SQL Compilations/sec%' )
			or
			( [object_name] like (@object_name+':SQL Statistics%') and counter_name like 'SQL Re-Compilations/sec%' )
			or
			( [object_name] like (@object_name+':SQL Statistics%') and [counter_name] like 'Auto-Param Attempts/sec%' )
			or
			( [object_name] like (@object_name+':SQL Statistics%') and [counter_name] like 'Failed Auto-Params/sec%' )
			or
			( [object_name] like (@object_name+':SQL Statistics%') and [counter_name] like 'Safe Auto-Params/sec%' )
			or
			( [object_name] like (@object_name+':SQL Statistics%') and [counter_name] like 'Unsafe Auto-Params/sec%' )
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Page lookups/sec%')
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Lazy writes/sec%')
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Page reads/sec%')
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Page writes/sec%')
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Logins/sec%')
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Free list stalls/sec%')
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Checkpoint pages/sec%')
			or
			( [object_name] like (@object_name+':Buffer Manager%') and counter_name like 'Readahead pages/sec%')
			or
			( [object_name] like (@object_name+':Locks%') and counter_name like 'Number of Deadlocks/sec%' )
			or
			( [object_name] like (@object_name+':Locks%') and counter_name like 'Lock Wait Time (ms)%')
			or
			( [object_name] like (@object_name+':Locks%') and counter_name like 'Lock Waits/sec%')
			or
			( [object_name] like (@object_name+':Latches%') and [counter_name] like 'Latch Waits/sec%' )
			or
			( [object_name] like (@object_name+':Latches%') and [counter_name] like 'Total Latch Wait Time (ms)%' )
			or
			( [object_name] like (@object_name+':Access Methods%') and counter_name like 'Full Scans/sec%')
			or
			( [object_name] like (@object_name+':Access Methods%') and counter_name like 'Forwarded Records/sec%')
			or
			( [object_name] like (@object_name+':Access Methods%') and counter_name like 'Index Searches/sec%')
			or
			( [object_name] like (@object_name+':Access Methods%') and counter_name like 'Page Splits/sec%')
			or
			( [object_name] like (@object_name+':Access Methods%') and counter_name like 'Workfiles Created/sec%')
			or
			( [object_name] like (@object_name+':Access Methods%') and counter_name like 'Worktables Created/sec%')
			or
			( [object_name] like (@object_name+':Access Methods%') and counter_name like 'Table Lock Escalations/sec%')
			or
			( [object_name] like (@object_name+':Databases%') and counter_name like 'Log Bytes Flushed/sec%')
			or
			( [object_name] like (@object_name+':Databases%') and counter_name like 'Log Flush Wait Time%')
			or
			( [object_name] like (@object_name+':Databases%') and counter_name like 'Log Flush Waits/sec%')
			or
			( [object_name] like (@object_name+':Databases%') and counter_name like 'Log Flushes/sec%')
			or
			( [object_name] like (@object_name+':SQL Errors%') and counter_name like 'Errors/sec%')
			or
			( [object_name] like (@object_name+':General Statistics%') and [counter_name] like 'Logins/sec%' )
			or
			( [object_name] like (@object_name+':General Statistics%') and [counter_name] like 'Logouts/sec%' )
		  );
		WITH Time_Samples AS (
			SELECT t1.collection_time as time1, t2.collection_time as time2,
					t1.object_name, t1.counter_name, t1.instance_name,
					t1.cntr_type as cntr_type_t1, t1.cntr_value as cntr_value_t1,
					t2.cntr_type as cntr_type_t2, t2.cntr_value as cntr_value_t2
			FROM #dm_os_performance_counters_PERF_COUNTER_BULK_COUNT_t1 as t1
			join #dm_os_performance_counters_PERF_COUNTER_BULK_COUNT_t2 as t2
			  on t1.collection_time < t2.collection_time and 
				 t2.object_name = t1.object_name and t2.counter_name = t1.counter_name and ISNULL(t2.instance_name,'') = ISNULL(t1.instance_name,'')
		)
		INSERT dbo.dm_os_performance_counters
		SELECT [collection_time] = SYSDATETIME(),
				server_name = @@SERVERNAME,
				object_name = rtrim(object_name),
				counter_name = rtrim(counter_name), 
				instance_name = rtrim(instance_name), 
				cntr_value = (cntr_value_t2-cntr_value_t1)/(DATEDIFF(SECOND,time1,time2))
				,cntr_type = cntr_type_t2
				,id = ROW_NUMBER()OVER(ORDER BY SYSDATETIME())
		FROM Time_Samples
		ORDER BY collection_time, server_name, [object_name], counter_name, id;
	end


	if @metrics = 'all' or @metrics = 'dm_os_ring_buffers'
	begin
		insert dbo.dm_os_ring_buffers
		SELECT collection_time, system_cpu_utilization, sql_cpu_utilization
		FROM (
				SELECT	top 1 EventTime as collection_time,  
						CASE WHEN system_cpu_utilization_post_sp2 IS NOT NULL THEN system_cpu_utilization_post_sp2 ELSE system_cpu_utilization_pre_sp2 END AS system_cpu_utilization,  
						CASE WHEN sql_cpu_utilization_post_sp2 IS NOT NULL THEN sql_cpu_utilization_post_sp2 ELSE sql_cpu_utilization_pre_sp2 END AS sql_cpu_utilization 
				--into dbo.dm_os_ring_buffers
				FROM  (	SELECT	record.value('(Record/@id)[1]', 'int') AS record_id,
								DATEADD (ms, -1 * (ts_now - [timestamp]), SYSDATETIME()) AS EventTime,
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
				ORDER BY EventTime desc
			 ) AS t
		WHERE NOT EXISTS (SELECT * FROM dbo.dm_os_ring_buffers as rfi where cast(rfi.collection_time as smalldatetime) = cast(t.collection_time as smalldatetime))
	end
end
GO

set nocount on;
exec dbo.usp_collect_performance_metrics @metrics = 'dm_os_sys_memory';
exec dbo.usp_collect_performance_metrics @metrics = 'dm_os_process_memory';
exec dbo.usp_collect_performance_metrics @metrics = 'dm_os_performance_counters';
exec dbo.usp_collect_performance_metrics @metrics = 'dm_os_performance_counters_sampling';
exec dbo.usp_collect_performance_metrics @metrics = 'dm_os_ring_buffers';
exec dbo.usp_collect_performance_metrics @metrics = 'dm_os_memory_clerks';
exec dbo.usp_collect_performance_metrics @metrics = 'dm_os_performance_counters_deprecated_features';
--exec msdb..sp_start_job @job_name = '(dba) Collect Performance Metrics - 2';
go


/*
USE [DBA]
GO
--	drop table dbo.[dm_os_performance_counters]
CREATE TABLE dbo.[dm_os_performance_counters]
(
	[collection_time] [datetime2] NOT NULL DEFAULT SYSDATETIME(),
	[server_name] varchar(256) NOT NULL DEFAULT @@SERVERNAME,
	[object_name] [nvarchar](128) NOT NULL,
	[counter_name] [nvarchar](128) NOT NULL,
	[instance_name] [nvarchar](128) NULL,
	[cntr_value] [bigint] NOT NULL,
	[cntr_type] [int] NOT NULL,
	[id] smallint NOT NULL
) ON [fg_ci]
GO
ALTER TABLE dbo.dm_os_performance_counters
   ADD CONSTRAINT pk_dm_os_performance_counters PRIMARY KEY CLUSTERED (collection_time, object_name, counter_name, id)
   WITH ( FILLFACTOR = 90, SORT_IN_TEMPDB = ON ) ON [fg_ci]
GO

-- drop table dbo.[dm_os_performance_counters_aggregated_90days]
CREATE TABLE dbo.[dm_os_performance_counters_aggregated_90days]
(
	[collection_time] [datetime2] NOT NULL,
	[server_name] varchar(256) NOT NULL DEFAULT @@SERVERNAME,
	[object_name] [nvarchar](128) NOT NULL,
	[counter_name] [nvarchar](128) NOT NULL,
	[instance_name] [nvarchar](128) NULL,
	[cntr_value] [bigint] NOT NULL,
	[cntr_type] [int] NOT NULL,
	[id] smallint NOT NULL
) ON [fg_archive]
GO
ALTER TABLE dbo.dm_os_performance_counters_aggregated_90days
   ADD CONSTRAINT pk_dm_os_performance_counters_aggregated_90days PRIMARY KEY CLUSTERED (collection_time, object_name, counter_name, id)
   WITH ( FILLFACTOR = 90, SORT_IN_TEMPDB = ON ) ON [fg_archive]
GO


-- drop table dbo.[dm_os_performance_counters_aggregated_1year]
CREATE TABLE dbo.[dm_os_performance_counters_aggregated_1year]
(
	[collection_time] [datetime2] NOT NULL,
	[server_name] varchar(256) NOT NULL DEFAULT @@SERVERNAME,
	[object_name] [nvarchar](128) NOT NULL,
	[counter_name] [nvarchar](128) NOT NULL,
	[instance_name] [nvarchar](128) NULL,
	[cntr_value] [bigint] NOT NULL,
	[cntr_type] [int] NOT NULL,
	[id] smallint NOT NULL
) ON [fg_archive]
GO
ALTER TABLE dbo.dm_os_performance_counters_aggregated_1year
   ADD CONSTRAINT pk_dm_os_performance_counters_aggregated_1year PRIMARY KEY CLUSTERED (collection_time, object_name, counter_name, id)
   WITH ( FILLFACTOR = 90, SORT_IN_TEMPDB = ON ) ON [fg_archive]
GO

-- drop view dbo.dm_os_performance_counters_aggregated
create view dbo.dm_os_performance_counters_aggregated
with schemabinding
as
select [collection_time], [server_name], [object_name], [counter_name], [instance_name], [cntr_value], [cntr_type], [id]
from [dbo].[dm_os_performance_counters_aggregated_90days]
union all
select [collection_time], [server_name], [object_name], [counter_name], [instance_name], [cntr_value], [cntr_type], [id]
from [dbo].[dm_os_performance_counters_aggregated_1year]
go


CREATE TABLE [dbo].[dm_os_sys_memory]
(
	[collection_time] [datetime2] NOT NULL DEFAULT SYSDATETIME(),
	[server_name] [nvarchar](128) NOT NULL DEFAULT @@SERVERNAME,
	[total_physical_memory_kb] [numeric](30, 2) NOT NULL,
	[available_physical_memory_kb] [numeric](30, 2) NOT NULL,
	[used_page_file_kb] [numeric](30, 2) NOT NULL,
	[system_cache_kb] [numeric](30, 2) NOT NULL,
	[free_memory_kb] [numeric](30, 2) NOT NULL,
	[system_memory_state_desc] [nvarchar](256) NOT NULL,
	[memory_usage_percentage] AS (cast(((total_physical_memory_kb-available_physical_memory_kb) * 100.0) / total_physical_memory_kb as numeric(20,2)))
) ON [fg_ci]
GO
ALTER TABLE [dbo].[dm_os_sys_memory]
   ADD CONSTRAINT pk_dm_os_sys_memory PRIMARY KEY CLUSTERED (collection_time) ON [fg_ci];
GO


-- drop table [dbo].[dm_os_sys_memory_aggregated]
CREATE TABLE [dbo].[dm_os_sys_memory_aggregated]
(
	[collection_time] [datetime2] NOT NULL,
	--[server_name] [nvarchar](128) NOT NULL,
	[total_physical_memory_kb] [numeric](30, 2) NOT NULL,
	[available_physical_memory_kb] [numeric](30, 2) NOT NULL,
	[used_page_file_kb] [numeric](30, 2) NOT NULL,
	[system_cache_kb] [numeric](30, 2) NOT NULL,
	[free_memory_kb] [numeric](30, 2) NOT NULL,
	--[system_memory_state_desc] [nvarchar](256) NOT NULL,
	[memory_usage_percentage] AS (cast(((total_physical_memory_kb-available_physical_memory_kb) * 100.0) / total_physical_memory_kb as numeric(20,2)))
)  ON [fg_archive]
GO
ALTER TABLE [dbo].[dm_os_sys_memory_aggregated] ADD CONSTRAINT pk_dm_os_sys_memory_aggregated PRIMARY KEY CLUSTERED (collection_time) ON [fg_archive];
GO


--DROP  TABLE [dbo].[dm_os_performance_counters_nonsql]
CREATE TABLE [dbo].[dm_os_performance_counters_nonsql]
(
	[collection_time] [datetime2] NOT NULL,
	[server_name] [varchar](256) NOT NULL,
	[object_name] [varchar](1024) NOT NULL,
	[counter_name] [varchar](1024) NOT NULL,
	[instance_name] [varchar](1024) NULL,
	[cntr_value] [float] NOT NULL,
	[cntr_type] [int] NOT NULL,
	[id] [smallint] NOT NULL
) ON [fg_ci]
GO
ALTER TABLE dbo.dm_os_performance_counters_nonsql
   ADD CONSTRAINT pk_dm_os_performance_counters_nonsql PRIMARY KEY CLUSTERED (collection_time, object_name, counter_name, id) ON [fg_ci];
GO


CREATE TABLE [dbo].[dm_os_performance_counters_nonsql_aggregated_90days]
(
	[collection_time] [datetime2] NOT NULL,
	[server_name] [varchar](256) NOT NULL,
	[object_name] [varchar](1024) NOT NULL,
	[counter_name] [varchar](1024) NOT NULL,
	[instance_name] [varchar](1024) NULL,
	[cntr_value] [float] NOT NULL,
	[cntr_type] [int] NOT NULL,
	[id] [smallint] NOT NULL
) ON [fg_archive]
GO
ALTER TABLE dbo.dm_os_performance_counters_nonsql_aggregated_90days
   ADD CONSTRAINT pk_dm_os_performance_counters_nonsql_aggregated_90days PRIMARY KEY CLUSTERED (collection_time, object_name, counter_name, id)
   ON [fg_archive];
GO

CREATE TABLE [dbo].[dm_os_performance_counters_nonsql_aggregated_1year]
(
	[collection_time] [datetime2] NOT NULL,
	[server_name] [varchar](256) NOT NULL,
	[object_name] [varchar](1024) NOT NULL,
	[counter_name] [varchar](1024) NOT NULL,
	[instance_name] [varchar](1024) NULL,
	[cntr_value] [float] NOT NULL,
	[cntr_type] [int] NOT NULL,
	[id] [smallint] NOT NULL
) ON [fg_archive]
GO
ALTER TABLE dbo.dm_os_performance_counters_nonsql_aggregated_1year
   ADD CONSTRAINT pk_dm_os_performance_counters_nonsql_aggregated_1year PRIMARY KEY CLUSTERED (collection_time, object_name, counter_name, id)
   ON [fg_archive];
GO

create view dbo.dm_os_performance_counters_nonsql_aggregated
with schemabinding
as
select [collection_time], [server_name], [object_name], [counter_name], [instance_name], [cntr_value], [cntr_type], [id]
from [dbo].[dm_os_performance_counters_nonsql_aggregated_90days]
union all
select [collection_time], [server_name], [object_name], [counter_name], [instance_name], [cntr_value], [cntr_type], [id]
from [dbo].[dm_os_performance_counters_nonsql_aggregated_1year]
go


--DROP TABLE [dbo].[dm_os_sys_info]
CREATE TABLE [dbo].[dm_os_sys_info]
(
	[collection_time] [datetime2] NOT NULL,
	[server_name] [varchar](256) NOT NULL,
	[sqlserver_start_time] [datetime] NOT NULL,
	[wait_stats_cleared_time] [smalldatetime] NOT NULL,
	[cpu_count] [smallint] NOT NULL,
	[physical_memory_kb] [bigint] NOT NULL,
	[max_workers_count] [smallint] NOT NULL,
	[virtual_machine_type] [int] NOT NULL,
	[softnuma_configuration_desc] [varchar](256) NOT NULL,
	[socket_count] [tinyint] NOT NULL,
	[cores_per_socket] [smallint] NOT NULL,
	[numa_node_count] [tinyint] NOT NULL
) ON [fg_ci]
GO
ALTER TABLE [dbo].[dm_os_sys_info]
   ADD CONSTRAINT pk_dm_os_sys_info PRIMARY KEY CLUSTERED (collection_time) ON [fg_ci];
GO
CREATE NONCLUSTERED INDEX nci_dm_os_sys_info__sqlserver_start_time__wait_stats_cleared_time
	ON [dbo].[dm_os_sys_info] (sqlserver_start_time, wait_stats_cleared_time) ON [fg_nci]
GO


--	drop table [dbo].[WaitStats]
CREATE TABLE [dbo].[WaitStats]
(
	[Collection_Time] [datetime2](7) NOT NULL,
	[RowNum] [smallint] NOT NULL,
	[WaitType] [nvarchar](120) NOT NULL,
	[Wait_S] [decimal](20, 2) NOT NULL,
	[Resource_S] [decimal](20, 2) NOT NULL,
	[Signal_S] [decimal](20, 2) NOT NULL,
	[WaitCount] [bigint] NOT NULL,
	[Percentage] [decimal](5, 2) NULL,
	--[Percentage] AS ([Wait_S]*100)/SUM([Wait_S])OVER(PARTITION BY [CollectionTime]),
	[AvgWait_S] AS ([Wait_S]/[WaitCount]),
	[AvgRes_S] AS ([Resource_S]/[WaitCount]),
	[AvgSig_S] AS ([Signal_S]/[WaitCount]),
	[Help_URL] AS (CONVERT([xml],'https://www.sqlskills.com/help/waits/'+[WaitType]))
) ON [fg_ci]
GO
ALTER TABLE dbo.WaitStats
   ADD CONSTRAINT pk_WaitStats PRIMARY KEY CLUSTERED (Collection_Time, RowNum, WaitType) ON [fg_ci];
GO


--	drop table [dbo].[WaitStats_aggregated]
CREATE TABLE [dbo].[WaitStats_aggregated]
(
	[Collection_Time] [datetime2] NOT NULL,
	[RowNum] [smallint] NOT NULL,
	[WaitType] [nvarchar](120) NOT NULL,
	[Wait_S] [decimal](20, 2) NOT NULL,
	[Resource_S] [decimal](20, 2) NOT NULL,
	[Signal_S] [decimal](20, 2) NOT NULL,
	[WaitCount] [bigint] NOT NULL,
	[Percentage] [decimal](5, 2) NULL,
	--[Percentage] AS ([Wait_S]*100)/SUM([Wait_S])OVER(PARTITION BY [CollectionTime]),
	[AvgWait_S] AS ([Wait_S]/[WaitCount]),
	[AvgRes_S] AS ([Resource_S]/[WaitCount]),
	[AvgSig_S] AS ([Signal_S]/[WaitCount]),
	[Help_URL] AS (CONVERT([xml],'https://www.sqlskills.com/help/waits/'+[WaitType]))
) ON [fg_archive]
GO
ALTER TABLE dbo.WaitStats_aggregated
   ADD CONSTRAINT pk_WaitStats_aggregated PRIMARY KEY CLUSTERED (Collection_Time, RowNum, WaitType)  ON [fg_archive];
GO


CREATE TABLE [dbo].[dm_os_process_memory]
(
	[collection_time] [datetime2] NOT NULL DEFAULT SYSDATETIME(),
	[SQL Server Memory Usage (MB)] [bigint] NULL,
	[page_fault_count] [bigint] NOT NULL,
	[memory_utilization_percentage] [int] NOT NULL,
	[available_commit_limit_kb] [bigint] NOT NULL,
	[process_physical_memory_low] [bit] NOT NULL,
	[process_virtual_memory_low] [bit] NOT NULL,
	[SQL Server Locked Pages Allocation (MB)] [bigint] NULL,
	[SQL Server Large Pages Allocation (MB)] [bigint] NULL
) ON [fg_ci]
GO
alter table [dbo].[dm_os_process_memory]
	add constraint pk_dm_os_process_memory primary key clustered (collection_time) ON [fg_ci]
go


CREATE TABLE [dbo].[dm_os_process_memory_aggregated]
(
	[collection_time] [datetime2] NOT NULL,
	[SQL Server Memory Usage (MB)] [bigint] NULL,
	[page_fault_count] [bigint] NOT NULL,
	[memory_utilization_percentage] [int] NOT NULL,
	[available_commit_limit_kb] [bigint] NOT NULL,
	[process_physical_memory_low] [bit] NOT NULL,
	[process_virtual_memory_low] [bit] NOT NULL,
	[SQL Server Locked Pages Allocation (MB)] [bigint] NULL,
	[SQL Server Large Pages Allocation (MB)] [bigint] NULL
) ON [fg_archive]
GO
alter table [dbo].[dm_os_process_memory_aggregated]
	add constraint pk_dm_os_process_memory_aggregated primary key clustered (collection_time) ON [fg_archive]
go


CREATE TABLE [dbo].[dm_os_ring_buffers]
(
	[collection_time] [datetime2] NOT NULL DEFAULT SYSDATETIME(),
	[system_cpu_utilization] [int] NOT NULL,
	[sql_cpu_utilization] [int] NOT NULL
) ON [fg_ci]
GO
alter table [dbo].[dm_os_ring_buffers]
	add constraint pk_dm_os_ring_buffers primary key clustered (collection_time) ON [fg_ci]
go


CREATE TABLE [dbo].[dm_os_ring_buffers_aggregated]
(
	[collection_time] [datetime2] NOT NULL,
	[system_cpu_utilization] [int] NOT NULL,
	[sql_cpu_utilization] [int] NOT NULL
) ON [fg_archive]
GO
alter table [dbo].[dm_os_ring_buffers_aggregated]
	add constraint pk_dm_os_ring_buffers_aggregated primary key clustered (collection_time) ON [fg_archive]
go


CREATE TABLE [dbo].[dm_os_memory_clerks]
(
	[collection_time] [datetime2] NOT NULL DEFAULT SYSDATETIME(),
	[memory_clerk] [nvarchar](60) NOT NULL,
	[size_mb] [bigint] NULL
) ON [fg_ci]
GO
alter table [dbo].[dm_os_memory_clerks]
	add constraint pk_dm_os_memory_clerks primary key clustered (collection_time,memory_clerk)
	ON [fg_ci]
go

-- drop table [dbo].[dm_os_memory_clerks_aggregated]
CREATE TABLE [dbo].[dm_os_memory_clerks_aggregated]
(
	[collection_time] [datetime2] NOT NULL,
	[memory_clerk] [nvarchar](60) NOT NULL,
	[size_mb] [bigint] NULL
) ON [fg_archive]
GO
alter table [dbo].[dm_os_memory_clerks_aggregated]
	add constraint pk_dm_os_memory_clerks_aggregated primary key clustered (collection_time,memory_clerk)
	ON [fg_archive]
go

USE [master]
GO
CREATE LOGIN [grafana] WITH PASSWORD=N'grafana', DEFAULT_DATABASE=[DBA], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO
GRANT VIEW SERVER STATE TO [grafana];
GO
USE [DBA]
GO
CREATE USER [grafana] FOR LOGIN [grafana]
GO
ALTER ROLE [db_datareader] ADD MEMBER [grafana]
GO

USE [master]
GO
EXEC master.dbo.sp_addlinkedserver @server = N'SQL-A\V17', @srvproduct=N'SQL Server'

GO
EXEC master.dbo.sp_serveroption @server=N'SQL-A\V17', @optname=N'collation compatible', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SQL-A\V17', @optname=N'data access', @optvalue=N'true'
GO
EXEC master.dbo.sp_serveroption @server=N'SQL-A\V17', @optname=N'dist', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SQL-A\V17', @optname=N'pub', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SQL-A\V17', @optname=N'rpc', @optvalue=N'true'
GO
EXEC master.dbo.sp_serveroption @server=N'SQL-A\V17', @optname=N'rpc out', @optvalue=N'true'
GO
EXEC master.dbo.sp_serveroption @server=N'SQL-A\V17', @optname=N'sub', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SQL-A\V17', @optname=N'connect timeout', @optvalue=N'120'
GO
EXEC master.dbo.sp_serveroption @server=N'SQL-A\V17', @optname=N'collation name', @optvalue=null
GO
EXEC master.dbo.sp_serveroption @server=N'SQL-A\V17', @optname=N'lazy schema validation', @optvalue=N'false'
GO
EXEC master.dbo.sp_serveroption @server=N'SQL-A\V17', @optname=N'query timeout', @optvalue=N'300'
GO
EXEC master.dbo.sp_serveroption @server=N'SQL-A\V17', @optname=N'use remote collation', @optvalue=N'true'
GO
EXEC master.dbo.sp_serveroption @server=N'SQL-A\V17', @optname=N'remote proc transaction promotion', @optvalue=N'true'
GO
USE [master]
GO
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = N'SQL-A\V17', @locallogin = NULL , @useself = N'False', @rmtuser = N'grafana', @rmtpassword = N'Pa$$w0rd'
GO


*/

/* *********************** For Multi Instance Scenario ********************************************
-- ************************ CAUTION *************************************************************--
use DBA
go

select @@SERVERNAME
go

if object_id('dbo.dm_os_performance_counters_nonsql') is not null
	drop table dbo.dm_os_performance_counters_nonsql;
go
create view dbo.dm_os_performance_counters_nonsql
as
select [collection_time], [server_name], [object_name], [counter_name], [instance_name], [cntr_value], [cntr_type], [id]
from [SQL-A].[DBA].[dbo].[dm_os_performance_counters_nonsql]
go

if object_id('dbo.dm_os_performance_counters_nonsql_aggregated') is not null
	drop view dbo.dm_os_performance_counters_nonsql_aggregated;
go
create view dbo.dm_os_performance_counters_nonsql_aggregated
as
select [collection_time], [server_name], [object_name], [counter_name], [instance_name], [cntr_value], [cntr_type], [id]
from [SQL-A].[DBA].[dbo].[dm_os_performance_counters_nonsql_aggregated_90days]
union all
select [collection_time], [server_name], [object_name], [counter_name], [instance_name], [cntr_value], [cntr_type], [id]
from [SQL-A].[DBA].[dbo].[dm_os_performance_counters_nonsql_aggregated_1year]
go

*/