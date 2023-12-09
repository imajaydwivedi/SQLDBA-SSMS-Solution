-- From SQLAuthority.com
SELECT TOP(50) DB_NAME(t.[dbid]) AS [Database Name], 
	t.text AS [Query Text],
	qs.total_worker_time AS [Total Worker Time], 
	qs.total_worker_time/qs.execution_count AS [Avg Worker Time], 
	qs.max_worker_time AS [Max Worker Time], 
	qs.total_elapsed_time/qs.execution_count AS [Avg Elapsed Time], 
	qs.max_elapsed_time AS [Max Elapsed Time],
	qs.total_logical_reads/qs.execution_count AS [Avg Logical Reads],
	qs.max_logical_reads AS [Max Logical Reads], 
	qs.execution_count AS [Execution Count], 
	qs.creation_time AS [Creation Time],
	qp.query_plan AS [Query Plan]
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
	CROSS APPLY sys.dm_exec_sql_text(plan_handle) AS t 
	CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp 
WHERE CAST(query_plan AS NVARCHAR(MAX)) LIKE ('%CONVERT_IMPLICIT%')
 AND t.[dbid] = DB_ID()
ORDER BY qs.total_worker_time DESC OPTION (RECOMPILE);


--Jonathan Kehayias
--http://sqlblog.com/blogs/jonathan_kehayias/archive/2010/01/08/finding-implicit-column-conversions-in-the-plan-cache.aspx

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED 

DECLARE @dbname SYSNAME 
SET @dbname = QUOTENAME(DB_NAME()); 

WITH XMLNAMESPACES 
   (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan') 
SELECT 
   stmt.value('(@StatementText)[1]', 'varchar(max)'), 
   t.value('(ScalarOperator/Identifier/ColumnReference/@Schema)[1]', 'varchar(128)'), 
   t.value('(ScalarOperator/Identifier/ColumnReference/@Table)[1]', 'varchar(128)'), 
   t.value('(ScalarOperator/Identifier/ColumnReference/@Column)[1]', 'varchar(128)'), 
   ic.DATA_TYPE AS ConvertFrom, 
   ic.CHARACTER_MAXIMUM_LENGTH AS ConvertFromLength, 
   t.value('(@DataType)[1]', 'varchar(128)') AS ConvertTo, 
   t.value('(@Length)[1]', 'int') AS ConvertToLength, 
   query_plan 
FROM sys.dm_exec_cached_plans AS cp 
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp 
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS batch(stmt) 
CROSS APPLY stmt.nodes('.//Convert[@Implicit="1"]') AS n(t) 
JOIN INFORMATION_SCHEMA.COLUMNS AS ic 
   ON QUOTENAME(ic.TABLE_SCHEMA) = t.value('(ScalarOperator/Identifier/ColumnReference/@Schema)[1]', 'varchar(128)') 
   AND QUOTENAME(ic.TABLE_NAME) = t.value('(ScalarOperator/Identifier/ColumnReference/@Table)[1]', 'varchar(128)') 
   AND ic.COLUMN_NAME = t.value('(ScalarOperator/Identifier/ColumnReference/@Column)[1]', 'varchar(128)') 
WHERE t.exist('ScalarOperator/Identifier/ColumnReference[@Database=sql:variable("@dbname")][@Schema!="[sys]"]') = 1;
GO

 /*----------------------------------------------------------------------
 Purpose: Identify columns having different datatypes, for the same column name.
		 Sorted by the prevalence of the mismatched column.
 ------------------------------------------------------------------------
 Revision History:
			06/01/2008  Ian_Stirk@yahoo.com Initial version.
 -----------------------------------------------------------------------*/
 -- Do not lock anything, and do not get held up by any locks.
 SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
 -- Calculate prevalence of column name
 SELECT
	   COLUMN_NAME
	   ,[%] = CONVERT(DECIMAL(12,2),COUNT(COLUMN_NAME)* 100.0 / COUNT(*)OVER())
 INTO #Prevalence
 FROM INFORMATION_SCHEMA.COLUMNS
 GROUP BY COLUMN_NAME
 -- Do the columns differ on datatype across the schemas and tables?
 SELECT DISTINCT
		 C1.COLUMN_NAME
	   , C1.TABLE_SCHEMA
	   , C1.TABLE_NAME
	   , C1.DATA_TYPE
	   , C1.CHARACTER_MAXIMUM_LENGTH
	   , C1.NUMERIC_PRECISION
	   , C1.NUMERIC_SCALE
	   , [%]
 FROM INFORMATION_SCHEMA.COLUMNS C1
 INNER JOIN INFORMATION_SCHEMA.COLUMNS C2 ON C1.COLUMN_NAME = C2.COLUMN_NAME
 INNER JOIN #Prevalence p ON p.COLUMN_NAME = C1.COLUMN_NAME
 WHERE ((C1.DATA_TYPE != C2.DATA_TYPE)
	   OR (C1.CHARACTER_MAXIMUM_LENGTH != C2.CHARACTER_MAXIMUM_LENGTH)
	   OR (C1.NUMERIC_PRECISION != C2.NUMERIC_PRECISION)
	   OR (C1.NUMERIC_SCALE != C2.NUMERIC_SCALE))
 ORDER BY [%] DESC, C1.COLUMN_NAME, C1.TABLE_SCHEMA, C1.TABLE_NAME
 -- Tidy up.
 DROP TABLE #Prevalence;
 GO