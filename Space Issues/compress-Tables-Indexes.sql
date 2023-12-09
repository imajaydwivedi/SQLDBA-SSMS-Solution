/*
Run in the database that will be compressed
*/

DECLARE @sqlcmd nvarchar(1000)


DECLARE compress_cursor CURSOR FOR
SELECT DISTINCT 'ALTER TABLE ' + '[' + s.[name] + ']'+'.' + '[' + o.[name] + ']' + ' REBUILD WITH (DATA_COMPRESSION=PAGE);'
FROM sys.objects AS o WITH (NOLOCK)
INNER JOIN sys.indexes AS i WITH (NOLOCK)
ON o.[object_id] = i.[object_id]
INNER JOIN sys.schemas AS s WITH (NOLOCK)
ON o.[schema_id] = s.[schema_id]
INNER JOIN sys.dm_db_partition_stats AS ps WITH (NOLOCK)
ON i.[object_id] = ps.[object_id]
AND ps.[index_id] = i.[index_id]
WHERE o.[type] = 'U'

UNION ALL

SELECT 'ALTER INDEX '+ '[' + i.[name] + ']' + ' ON ' + '[' + s.[name] + ']' + '.' + '[' + o.[name] + ']' + ' REBUILD WITH (DATA_COMPRESSION=PAGE);'
FROM sys.objects AS o WITH (NOLOCK)
INNER JOIN sys.indexes AS i WITH (NOLOCK)
ON o.[object_id] = i.[object_id]
INNER JOIN sys.schemas s WITH (NOLOCK)
ON o.[schema_id] = s.[schema_id]
INNER JOIN sys.dm_db_partition_stats AS ps WITH (NOLOCK)
ON i.[object_id] = ps.[object_id]
AND ps.[index_id] = i.[index_id]
WHERE o.type = 'U' AND i.[index_id] >0

 
OPEN compress_cursor;

FETCH NEXT FROM compress_cursor INTO @sqlcmd

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT @sqlcmd
    EXEC sp_executesql @sqlcmd
    FETCH NEXT FROM compress_cursor INTO @sqlcmd
END
CLOSE compress_cursor
DEALLOCATE compress_cursor