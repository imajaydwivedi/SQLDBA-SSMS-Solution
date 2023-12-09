/* HEADER */
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET QUOTED_IDENTIFIER OFF 
DECLARE @sql varchar(max) = "
USE [security_master];
SELECT 'security_master' AS database_name,sch.name + '.' + so.name AS object_name, so.type_desc AS object_type, ss.name AS statistics_name, 
       CASE
         WHEN ss.auto_Created = 0 AND ss.user_created = 0 THEN 'Index Statistic'
         WHEN ss.auto_created = 0 AND ss.user_created = 1 THEN 'User Created'
         WHEN ss.auto_created = 1 AND ss.user_created = 0 THEN 'Auto Created'
         WHEN ss.AUTO_created = 1 AND ss.user_created = 1 THEN 'Not Possible?'
       END AS statistics_type,
	   CASE
	     WHEN no_recompute = 0 THEN 'RECOMPUTE'
		 WHEN no_recompute = 1 THEN 'NORECOMPUTE'
		 END AS recompute_setting,
       CASE
         WHEN ss.has_filter = 1 THEN 'Filtered Index'
         WHEN ss.has_filter = 0 THEN 'No Filter'
       END AS filter_type,
       CASE
         WHEN ss.filter_definition IS NULL THEN ''
         WHEN ss.filter_definition IS NOT NULL THEN ss.filter_definition
       END AS filter_definition,
       sp.last_updated AS last_update_stats,
       FORMAT(sp.rows, '###,###,###') AS total_rows,
       FORMAT(sp.rows_sampled, '###,###,###') AS rows_sampled,
       FORMAT(sp.unfiltered_rows, '###,###,###') AS unfiltered_rows,
       FORMAT(sp.modification_counter, '###,###,###') AS row_modification_counter,
       sp.steps AS histogram_steps,
	   'UPDATE STATISTICS ' + QUOTENAME(sch.name) + '.' + QUOTENAME(so.name) + ' ' + QUOTENAME(ss.name) + ';' AS sql_update_stats
FROM [security_master].sys.objects AS so   
JOIN   [security_master].sys.schemas sch ON so.schema_id = sch.schema_id
INNER JOIN [security_master].sys.stats AS ss ON ss.object_id = so.object_id  
CROSS APPLY [security_master].sys.dm_db_stats_properties(ss.object_id, ss.stats_id) AS sp  
WHERE so.type_desc NOT IN ('SYSTEM_TABLE', 'INTERNAL_TABLE')
AND sch.name + '.' + so.name = '_sfs._td_bl_security_edit_lock'
ORDER BY object_name ASC, auto_created, statistics_name ASC
"
SET QUOTED_IDENTIFIER ON
IF ('MyProdServer' = SERVERPROPERTY('ServerName'))
BEGIN
  EXEC (@sql);
END;
ELSE
BEGIN
  EXEC (@sql) AT MyProdServer;
END;
GO


/* Histogram */
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET QUOTED_IDENTIFIER OFF 
DECLARE @sql varchar(max) = "
select sch.name + '.' + so.name AS object_name, ss.name as statistics_name, sp.step_number AS step, range_high_key, range_rows, equal_rows, distinct_range_rows, average_range_rows
FROM [security_master].sys.objects AS so   
JOIN [security_master].sys.schemas sch ON so.schema_id = sch.schema_id
INNER JOIN [security_master].sys.stats AS ss ON ss.object_id = so.object_id  
CROSS APPLY [security_master].sys.dm_db_stats_histogram(ss.object_id, ss.stats_id) AS sp  
WHERE sch.name + '.' + so.name = '_sfs._td_bl_security_edit_lock'
AND ss.name = 'tt_IX'
ORDER BY object_name, statistics_name, step_number;
"
SET QUOTED_IDENTIFIER ON
IF ('SqlProd2' = SERVERPROPERTY('ServerName'))
BEGIN
  EXEC (@sql);
END;
ELSE
BEGIN
  EXEC (@sql) AT SqlProd2;
END;



