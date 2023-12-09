/*
Kevin Kline, kkline@sentryone.com, @kekline on Twitter, LinkedIn, and Facebook

--Database Design : Naming standards
Inconsistent naming standards can cause confusion and even lead to plan cache
bloat. Look for the presence consistent and meaningful names.

Look for stored procedures starting with 'sp_', as well as inconsistent naming 
patterns: dbo.GetCustomerDetails, dbo.Customer_Update, dbo.Create_Customer, 
dbo.usp_updatecust all in the same database.
*/

SELECT o.name, SCHEMA_NAME(o.schema_id), o.type, o.type_desc, o.create_date, o.modify_date, o.is_ms_shipped
FROM sys.objects AS o
WHERE o.type NOT IN('IT', 'SQ', 'S') 
  AND o.is_ms_shipped = 0
ORDER BY o.type, o.type_desc; 


/*
-- Database Design : Data Type Issues : Oversize columns
Some developers and many ORMs consistently oversize the columns of their tables
compared to the amount of data actually stored, resulting in wasted space.
 
This script compares the column length according to the metadata versus the 
length of data actually in the column. 
*/

SET NOCOUNT ON;

DECLARE @table_schema   NVARCHAR(128);
DECLARE @table_name     NVARCHAR(128);
DECLARE @column_name    NVARCHAR(128);
DECLARE @parms          NVARCHAR(100);
DECLARE @data_type      NVARCHAR(128);
DECLARE @character_maximum_length   INT;
DECLARE @max_len        NVARCHAR(10);
DECLARE @tsql           NVARCHAR(4000);

DECLARE DDLCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
      table_schema,
      table_name,
      column_name,
      data_type,
      character_maximum_length
    FROM information_schema.columns
    WHERE table_name IN (SELECT table_name
                     FROM information_schema.tables
                     WHERE table_type = 'BASE TABLE') 
	AND data_type IN ('char', 'nchar', 'varchar', 'nvarchar') 
	AND character_maximum_length > 1

OPEN DDLCursor;
-- Should rewrite using sp_MSforeachtable instead of explicit cursor

SET @PARMS = N'@MAX_LENout nvarchar(10) OUTPUT';

CREATE TABLE #space(
  table_schema               NVARCHAR(128) NOT NULL,
  table_name                 NVARCHAR(128) NOT NULL,
  column_name                NVARCHAR(128) NOT NULL,
  data_type                  NVARCHAR(128) NOT NULL,
  character_maximum_length   INT NOT NULL,
  actual_maximum_length      INT NOT NULL);

-- Perform the first fetch.

FETCH NEXT FROM DDLCursor
INTO
  @table_schema,
  @table_name,
  @column_name,
  @data_type,
  @character_maximum_length;

-- Check @@FETCH_STATUS to see if there are any more rows to fetch.

WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @tsql      = 'select @MAX_LENout = cast(max(len(isnull(' +
                     QUOTENAME(@COLUMN_NAME) +
                     ',''''))) as nvarchar(10)) from ' +
                     QUOTENAME(@TABLE_SCHEMA) +
                     '.' +
                     QUOTENAME(@TABLE_NAME);
    EXEC sp_executesql @tsql,
                       @PARMS,
                       @MAX_LENout = @MAX_LEN OUTPUT ;

    IF CAST(@MAX_LEN AS INT) < @CHARACTER_MAXIMUM_LENGTH -- not interested if lengths match
      BEGIN
        SET @tsql      = 'insert into #space values (''' +
                         @table_schema +
                         ''',''' +
                         @table_name +
                         ''',''' +
                         @column_name +
                         ''',''' +
                         @data_type +
                         ''',' +
                         CAST(@character_maximum_length AS NVARCHAR(10)) +
                         ',' +
                         @max_len +
                         ')';
        EXEC sp_executesql @tsql ;
      END;

    -- This is executed as long as the previous fetch succeeds.

    FETCH NEXT FROM DDLCursor
    INTO
      @table_schema,
      @table_name,
      @column_name,
      @data_type,
      @character_maximum_length;
  END;

CLOSE DDLCursor;
DEALLOCATE DDLCursor;

SELECT * FROM #space;
DROP TABLE #space;
GO

/* 
--Proper and consistent use of indexes.
First, find all tables without any clustered indexes and/or non-clustered indexes.
If there are more than a handful of very small tables without clustered indexes,
then clustered indexes should be created on them. If the tables will be large and 
have columns used in search arguments, like WHERE clauses or JOIN clauses, then 
indexes should probably be created there too.

Original author, Davide Mauri at http://sqlblog.com/blogs/davide_mauri/archive/2010/08/09/find-all-the-tables-with-no-indexes-at-all.aspx
*/

WITH CTE AS 
( 
    SELECT 
        table_name = o.name,    
        o.[object_id], 
        i.index_id, 
        i.type, 
        i.type_desc 
    FROM sys.indexes i 
		INNER JOIN  sys.objects o ON i.[object_id] = o.[object_id] 
    WHERE o.type in ('U') 
      AND o.is_ms_shipped = 0 AND i.is_disabled = 0  AND i.is_hypothetical = 0 
      AND i.type <= 2 
), 
cte2 AS 
( 
SELECT * 
FROM cte c 
	PIVOT (COUNT(type) FOR type_desc IN ([HEAP], [CLUSTERED], [NONCLUSTERED])) pv ) 
SELECT 
    c2.table_name, 
    [rows] = max(p.rows), 
    is_heap = sum([HEAP]), 
    is_clustered = sum([CLUSTERED]), 
    num_of_nonclustered = sum([NONCLUSTERED]) 
FROM cte2 c2 
	INNER JOIN sys.partitions p ON c2.[object_id] = p.[object_id] and c2.index_id = p.index_id 
GROUP BY table_name;

/* 
-- Proper and consistent use of keys and constraints: Primary Key. This is a 
quick indicator of the VERY WORST sort of database design habits. If your 
vendor doesn't have primary keys, they very likely don't know anything about 
databases. Expect LOTS of other problems!

*/

SELECT t.name 'Tables without Primary Keys'
FROM sys.tables T
WHERE OBJECTPROPERTY(object_id,'TableHasPrimaryKey') = 0
      AND type = 'U';

/* 
-- Proper and consistent use of keys and constraints: Foreign Keys. 
While not as critical as primary keys, foreign keys are very important for 
defending against insert, update, and delete anomalies on relational database.
Just as bad as having no foreign keys is having foreign keys that are not 
also indexed. 

In a more detailed session, we would look at other types of constraints: 
unique, default, and check. Check out https://msdn.microsoft.com/en-us/library/ms176105.aspx
for details on how to look up tables with those kinds of constraints and check
to see if the columns with those constraints are properly indexed.
*/
SELECT t.name 'Tables without Foreign Keys'
FROM sys.tables T
WHERE OBJECTPROPERTY(object_id,'TableHasForeignKey') = 0
      AND type = 'U';

SELECT t.name 'Tables has Foreign Keys but no Non-clustered indexes'
FROM sys.tables T
WHERE OBJECTPROPERTY(object_id,'TableHasForeignKey') = 1
	AND OBJECTPROPERTY(object_id,'TableHasNonclustIndex') = 0
    AND type = 'U';

/* 
-- Missing Index Warnings
SQL Server is on the lookout for queries that would have benefitted from
having an index. DO NOT blindly apply its recommendations. However, if you
have a query that lacked an index on a column that clearly needed on because
many other queries also search upon that column, then it's probably useful to
add it. $$$

In the query below by Ian Stirk (ian.stirk@yahoo.com) and popularized by Glenn
Berry (http://sqlserverperformance.wordpress.com/), you should look at index 
advantage, last user seek time, number of user seeks to help determine source and 
importance. SQL Server is overly eager to add included columns, so beware.
Do not just blindly add indexes that show up from this query!!!
*/

-- Missing Indexes for current database by Index Advantage 
 SELECT DISTINCT CONVERT( DECIMAL ( 18 ,2 ) ,user_seeks * avg_total_user_cost * ( avg_user_impact * 0.01 ) ) AS [index_advantage]
    ,migs.last_user_seek
    ,mid.[statement] AS [Database.Schema.Table]
    ,mid.equality_columns
    ,mid.inequality_columns
    ,mid.included_columns
    ,migs.unique_compiles
    ,migs.user_seeks
    ,migs.avg_total_user_cost
    ,migs.avg_user_impact
    ,OBJECT_NAME (mid.[object_id]) AS [Table Name]
    ,p.rows AS [Table Rows]
FROM sys.dm_db_missing_index_group_stats AS migs WITH (NOLOCK) 
	INNER JOIN sys.dm_db_missing_index_groups AS mig WITH (NOLOCK)
        ON migs.group_handle = mig.index_group_handle 
	INNER JOIN sys.dm_db_missing_index_details AS mid WITH (NOLOCK)
        ON mig.index_handle = mid.index_handle 
	INNER JOIN sys.partitions AS p WITH (NOLOCK)
        ON p.[object_id] = mid.[object_id]
WHERE mid.database_id = DB_ID ()
ORDER BY index_advantage DESC OPTION (RECOMPILE);

/*
-- Tables with duplicate indexes. 
That is, an index is a duplicate if it references the same column and ordinal position 
as another index in the same database. Duplicate indexes provide no benefits, while also
increasing the I/O overhead of ongoing write operations, as well as defrag operations. 

The overall result is write performance, wasted disk space, and longer index maintenance 
operations. 

Drop duplicate indexes to get an immediate performance benefit for write operations and also 
for index rebuilds and reorgs. Existing queries should be unaffected.
*/

;WITH IndexColumns AS(
select distinct  schema_name (o.schema_id) as 'SchemaName',object_name(o.object_id) as TableName, i.Name as IndexName, o.object_id,i.index_id,i.type,
(select case key_ordinal when 0 then NULL else '['+col_name(k.object_id,column_id) +'] ' + CASE WHEN is_descending_key=1 THEN 'Desc' ELSE 'Asc' END end as [data()]
from sys.index_columns  (NOLOCK) as k
where k.object_id = i.object_id
  and k.index_id = i.index_id
order by key_ordinal, column_id
for xml path('')) as cols,
case when i.index_id=1 then 
(select '['+name+']' as [data()]
from sys.columns  (NOLOCK) as c
where c.object_id = i.object_id
  and c.column_id not in (select column_id from sys.index_columns  (NOLOCK) as kk    
							where kk.object_id = i.object_id and kk.index_id = i.index_id)
order by column_id
for xml path(''))
else (select '['+col_name(k.object_id,column_id) +']' as [data()]
from sys.index_columns  (NOLOCK) as k
where k.object_id = i.object_id
and k.index_id = i.index_id and is_included_column=1 and k.column_id not in (Select column_id from sys.index_columns kk where k.object_id=kk.object_id and kk.index_id=1)
order by key_ordinal, column_id
for xml path('')) end as inc
from sys.indexes  (NOLOCK) as i
	inner join sys.objects o  (NOLOCK) on i.object_id =o.object_id 
	inner join sys.index_columns ic  (NOLOCK) on ic.object_id =i.object_id and ic.index_id =i.index_id
	inner join sys.columns c  (NOLOCK) on c.object_id = ic.object_id and c.column_id = ic.column_id
where  o.type = 'U' and i.index_id <>0 and i.type <>3 and i.type <>5 and i.type <>6 and i.type <>7 
group by o.schema_id,o.object_id,i.object_id,i.Name,i.index_id,i.type
),
DuplicatesTable AS
(SELECT    ic1.SchemaName,ic1.TableName,ic1.IndexName,ic1.object_id, ic2.IndexName as DuplicateIndexName, 
CASE WHEN ic1.index_id=1 THEN ic1.cols + ' (Clustered)' WHEN ic1.inc = '' THEN ic1.cols  WHEN ic1.inc is NULL THEN ic1.cols ELSE ic1.cols + ' INCLUDE ' + ic1.inc END as IndexCols, 
ic1.index_id
from IndexColumns ic1 join IndexColumns ic2 on ic1.object_id = ic2.object_id
and ic1.index_id < ic2.index_id and ic1.cols = ic2.cols
and (ISNULL(ic1.inc,'') = ISNULL(ic2.inc,'')  OR ic1.index_id=1 )
)
SELECT SchemaName,TableName, IndexName,DuplicateIndexName, IndexCols, index_id, object_id, 0 AS IsXML
FROM DuplicatesTable dt
ORDER BY 1,2,3;

/*
-- Red flags about database design provided by PerfMon counters
Run this query after running a workload, such as in a software POC or after a live demo.

Forwarded records indicate a serious design flaw for the database. $$$
*/
SELECT  RTRIM([object_name]) + N':' + RTRIM([counter_name]) + N':'
                + RTRIM([instance_name]) ,
                [cntr_type] ,
                [cntr_value] 
FROM    sys.dm_os_performance_counters
WHERE   [counter_name] IN 
		( N'Number of Deadlocks/sec',
          N'Forwarded Records/sec',
          N'Full Scans/sec',
          N'Batch Requests/sec',
          N'SQL Compilations/sec',
          N'SQL Re-Compilations/sec')
ORDER BY [object_name] + N':' + [counter_name] + N':' + [instance_name];
GO

/*
-- Lookups
This query shows full table scans and key lookups caused by user activity.
Full table scans are only a problem on large tables, and even then only if they 
happen frequently. Lookups a drag on performs. A few are not unusual, but if a 
vendor app has many of these on many objec ts, it means that database design is 
low quality. 

This query only identifies that they are happening. To fix them, read more at
--http://kendalvandyke.blogspot.com/2010/07/finding-key-lookups-in-cached-execution.html
*/

SELECT DISTINCT DB_NAME(database_id), OBJECT_NAME(object_id), user_scans, user_lookups
FROM sys.dm_db_index_usage_stats
WHERE (user_scans > 0 OR user_lookups > 0)
  AND database_id = DB_ID();
