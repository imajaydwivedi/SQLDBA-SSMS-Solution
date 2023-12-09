--	https://www.sqlskills.com/blogs/kimberly/plan-cache-adhoc-workloads-and-clearing-the-single-use-plan-cache-bloat/
--	https://www.sqlskills.com/blogs/kimberly/plan-cache-and-optimizing-for-adhoc-workloads/
--	https://www.sqlshack.com/searching-the-sql-server-query-plan-cache/
--	https://sqlperformance.com/2014/10/t-sql-queries/performance-tuning-whole-plan


/* Query plans with Warnings */
;WITH XMLNAMESPACES
    (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')   
SELECT TOP 20
	dm_exec_sql_text.text AS sql_text,
	CAST(CAST(dm_exec_query_stats.execution_count AS DECIMAL) / CAST((CASE WHEN DATEDIFF(HOUR, dm_exec_query_stats.creation_time, CURRENT_TIMESTAMP) = 0 THEN 1 ELSE DATEDIFF(HOUR, dm_exec_query_stats.creation_time, CURRENT_TIMESTAMP) END) AS DECIMAL) AS INT) AS executions_per_hour,
	dm_exec_query_stats.creation_time, 
	dm_exec_query_stats.execution_count,
	CAST(CAST(dm_exec_query_stats.total_worker_time AS DECIMAL)/CAST(dm_exec_query_stats.execution_count AS DECIMAL) AS INT) as cpu_per_execution,
	CAST(CAST(dm_exec_query_stats.total_logical_reads AS DECIMAL)/CAST(dm_exec_query_stats.execution_count AS DECIMAL) AS INT) as logical_reads_per_execution,
	CAST(CAST(dm_exec_query_stats.total_elapsed_time AS DECIMAL)/CAST(dm_exec_query_stats.execution_count AS DECIMAL) AS INT) as elapsed_time_per_execution,
	dm_exec_query_stats.total_worker_time AS total_cpu_time,
	dm_exec_query_stats.max_worker_time AS max_cpu_time, 
	dm_exec_query_stats.total_elapsed_time, 
	dm_exec_query_stats.max_elapsed_time, 
	dm_exec_query_stats.total_logical_reads, 
	dm_exec_query_stats.max_logical_reads,
	dm_exec_query_stats.total_physical_reads, 
	dm_exec_query_stats.max_physical_reads,
	dm_exec_query_plan.query_plan
FROM sys.dm_exec_query_stats
CROSS APPLY sys.dm_exec_sql_text(dm_exec_query_stats.sql_handle)
CROSS APPLY sys.dm_exec_query_plan(dm_exec_query_stats.plan_handle)
WHERE query_plan.exist('//Warnings') = 1
AND query_plan.exist('//ColumnReference[@Database = "[YouTubeMusic]"]') = 1
ORDER BY dm_exec_query_stats.total_worker_time DESC;
 
/* Plans with Table/Clustered Index Scan */
;WITH XMLNAMESPACES
    (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')   
SELECT
	dm_exec_sql_text.text AS sql_text,
	CAST(CAST(dm_exec_query_stats.execution_count AS DECIMAL) / CAST((CASE WHEN DATEDIFF(HOUR, dm_exec_query_stats.creation_time, CURRENT_TIMESTAMP) = 0 THEN 1 ELSE DATEDIFF(HOUR, dm_exec_query_stats.creation_time, CURRENT_TIMESTAMP) END) AS DECIMAL) AS INT) AS executions_per_hour,
	dm_exec_query_stats.creation_time, 
	dm_exec_query_stats.execution_count,
	CAST(CAST(dm_exec_query_stats.total_worker_time AS DECIMAL)/CAST(dm_exec_query_stats.execution_count AS DECIMAL) AS INT) as cpu_per_execution,
	CAST(CAST(dm_exec_query_stats.total_logical_reads AS DECIMAL)/CAST(dm_exec_query_stats.execution_count AS DECIMAL) AS INT) as logical_reads_per_execution,
	CAST(CAST(dm_exec_query_stats.total_elapsed_time AS DECIMAL)/CAST(dm_exec_query_stats.execution_count AS DECIMAL) AS INT) as elapsed_time_per_execution,
	dm_exec_query_stats.total_worker_time AS total_cpu_time,
	dm_exec_query_stats.max_worker_time AS max_cpu_time, 
	dm_exec_query_stats.total_elapsed_time, 
	dm_exec_query_stats.max_elapsed_time, 
	dm_exec_query_stats.total_logical_reads, 
	dm_exec_query_stats.max_logical_reads,
	dm_exec_query_stats.total_physical_reads, 
	dm_exec_query_stats.max_physical_reads,
	dm_exec_query_plan.query_plan
FROM sys.dm_exec_query_stats
CROSS APPLY sys.dm_exec_sql_text(dm_exec_query_stats.sql_handle)
CROSS APPLY sys.dm_exec_query_plan(dm_exec_query_stats.plan_handle)
WHERE (query_plan.exist('//RelOp[@PhysicalOp = "Index Scan"]') = 1
	   OR query_plan.exist('//RelOp[@PhysicalOp = "Clustered Index Scan"]') = 1)
AND query_plan.exist('//ColumnReference[@Database = "[AdventureWorks2014]"]') = 1
ORDER BY dm_exec_query_stats.total_worker_time DESC;
 