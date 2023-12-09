SET NOCOUNT ON;

DECLARE @_dbName VARCHAR(2000);
SET @_dbName = NULL;

DECLARE @_sqlString NVARCHAR(MAX);
IF OBJECT_ID('tempdb..#TableSizeMetrics') IS NOT NULL
	DROP TABLE #TableSizeMetrics;
CREATE TABLE #TableSizeMetrics
(
	[DbName] [nvarchar](128) NULL,
	[object_id] [int] NOT NULL,
	[table_name] [nvarchar](257) NOT NULL,
	[type_desc] [nvarchar](120) NULL,
	[modify_date] [datetime] NOT NULL,
	[IndexName] [sysname] NULL,
	[index_type_desc] [nvarchar](60) NULL,
	[fill_factor] [tinyint] NOT NULL,
	[total_Table_rows] [bigint] NULL,
	[total_pages] [bigint] NULL,
	[size(MB)] [decimal](36, 2) NULL
) 

DECLARE dbCursor CURSOR LOCAL STATIC FORWARD_ONLY FOR
	SELECT d.name FROM sys.databases as d where d.is_read_only = 0 and d.is_in_standby = 0 and d.database_id > 4 and d.state_desc = 'ONLINE'
		AND (@_dbName IS NULL OR d.name = @_dbName);

OPEN dbCursor;
FETCH NEXT FROM dbCursor INTO @_dbName;

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @_sqlString = '
USE ['+@_dbName+'];
SELECT	[DbName] = DB_NAME()
		,t.[object_id]
		,[table_name] = s.[Name] + ''.'' + t.[name]
		,t.[type_desc], t.modify_date
		,[IndexName] = i.[name]
		,[index_type_desc] = i.[type_desc]
		,i.fill_factor 
		,p.[total_Table_rows]
		,[total_pages] = a.total_Index_pages
		,[size(MB)] = convert(decimal(36,2),(a.total_Index_pages * 8.0)/1024)
    FROM 
        sys.tables t
    INNER JOIN 
        sys.schemas s ON s.schema_id = t.schema_id
    INNER JOIN      
        sys.indexes i ON t.OBJECT_ID = i.object_id
    OUTER APPLY (
			SELECT SUM(P.rows) AS [total_Table_rows] 
			FROM sys.partitions p
			WHERE i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
		) p
	OUTER APPLY (
			SELECT [total_Index_pages] = SUM(a.total_pages)
			FROM sys.partitions p INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
			WHERE i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
		) a
    WHERE 
        t.is_ms_shipped = 0 AND i.OBJECT_ID > 255
	ORDER BY DB_NAME(), s.Name, t.name, i.name;
';
	
	--PRINT @_sqlString;
	INSERT #TableSizeMetrics
	EXEC (@_sqlString);

	FETCH NEXT FROM dbCursor INTO @_dbName;
END

CLOSE dbCursor;
DEALLOCATE dbCursor;

SELECT * FROM #TableSizeMetrics;