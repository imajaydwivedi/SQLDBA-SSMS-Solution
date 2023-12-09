USE SQLWATCH
GO
-- collection_time BETWEEN master.dbo.utc2local($__timeFrom()) AND master.dbo.utc2local($__timeTo())
-- report_time is local server time

SELECT TOP 100 *
FROM [dbo].[vw_sqlwatch_report_fact_perf_os_performance_counters] as pc
WHERE pc.counter_name = 'Processor Time %'
ORDER BY report_time DESC

SELECT /* SQLWATCH - Overview => SQL Server Activity */
      [time] = [report_time]
      ,metric = [counter_name]
      ,[value] = FLOOR([cntr_value_calculated])
FROM SQLWATCH.[dbo].[vw_sqlwatch_report_fact_perf_os_performance_counters]
WHERE $__timeFilter(snapshot_time)
  AND counter_name IN ('Batch Requests/sec','Logins/sec','Transactions/sec','User Connections','SQL Compilations/sec','SQL Re-Compilations/sec')
  AND [sql_instance] = 'MSI'
ORDER BY
  time ASC

;WITH T_Metrics AS (
	SELECT /* SQLWATCH - Overview => SQL Server Activity */
		  [time] = [report_time]
		  ,metric = [counter_name]
		  ,[value] = FLOOR([cntr_value_calculated])
	FROM [dbo].[vw_sqlwatch_report_fact_perf_os_performance_counters]
	WHERE snapshot_time BETWEEN '2020-08-16T03:34:10Z' AND '2020-08-16T03:49:10Z'
	  AND counter_name IN ('Batch Requests/sec','Logins/sec','Transactions/sec','User Connections','SQL Compilations/sec','SQL Re-Compilations/sec')
	  AND [sql_instance] = 'MSI'
)
SELECT time, [Batch Requests/sec],[Logins/sec],[SQL Compilations/sec],[SQL Re-Compilations/sec],[Transactions/sec],[User Connections]
FROM T_Metrics as up
PIVOT (MAX([value]) FOR metric IN ([Batch Requests/sec],[Logins/sec],[SQL Compilations/sec],[SQL Re-Compilations/sec],[Transactions/sec],[User Connections])) as pvt
ORDER BY
  time desc