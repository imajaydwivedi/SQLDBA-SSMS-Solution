/*
This script estimates compression savings for all objects, indexes, and partitions in the current database.

See http://blogs.msdn.com/b/dfurman/archive/2011/02/25/estimating-data-compression-savings-for-entire-database.aspx for details.
*/
use Galaxy;

DECLARE @CompressionSavingsEstimate table
(
SchemaName sysname NOT NULL,
ObjectName sysname NOT NULL,
IndexName sysname NOT NULL,
IndexType nvarchar(60) NOT NULL,
PartitionNum int NOT NULL,
CompressionType nvarchar(10) NOT NULL,
[size_with_current_compression_setting (KB)] bigint NOT NULL,
[size_with_requested_compression_setting (KB)] bigint NOT NULL,
[sample_size_with_current_compression_setting (KB)] bigint NOT NULL,
[sample_size_with_requested_compression_setting (KB)] bigint NOT NULL,
PRIMARY KEY (SchemaName, ObjectName, IndexName, IndexType, PartitionNum, CompressionType)
);
DECLARE @ProcResult table
(
[object_name] sysname NOT NULL,
[schema_name] sysname NOT NULL,
[index_id] int NOT NULL,
[partition_number] int NOT NULL,
[size_with_current_compression_setting (KB)] bigint NOT NULL,
[size_with_requested_compression_setting (KB)] bigint NOT NULL,
[sample_size_with_current_compression_setting (KB)] bigint NOT NULL,
[sample_size_with_requested_compression_setting (KB)] bigint NOT NULL
);
DECLARE @SchemaName sysname;
DECLARE @ObjectName sysname;
DECLARE @IndexID int;
DECLARE @IndexName sysname;
DECLARE @IndexType nvarchar(60);
DECLARE @PartitionNum int;
DECLARE @CompTypeNum tinyint;
DECLARE @CompressionType nvarchar(60);

SET NOCOUNT ON;

DECLARE CompressedIndex INSENSITIVE CURSOR FOR
SELECT s.name AS SchemaName,
       o.name AS ObjectName,
       i.index_id AS IndexID,
       COALESCE(i.name, '<HEAP>') AS IndexName,
       i.type_desc AS IndexType,
       p.partition_number AS PartitionNum
FROM sys.schemas AS s
INNER JOIN sys.objects AS o
ON s.schema_id = o.schema_id
INNER JOIN sys.indexes AS i
ON o.object_id = i.object_id
INNER JOIN sys.partitions AS p
ON o.object_id = p.object_id
   AND
   i.index_id = p.index_id
WHERE o.type_desc IN ('USER_TABLE','VIEW');
   
OPEN CompressedIndex;

WHILE 1 = 1
BEGIN
    FETCH NEXT FROM CompressedIndex 
    INTO @SchemaName, @ObjectName, @IndexID, @IndexName, @IndexType, @PartitionNum;

    IF @@FETCH_STATUS <> 0
        BREAK;

    SELECT @CompTypeNum = 0;
    WHILE @CompTypeNum <= 2
    BEGIN
        SELECT @CompressionType = CASE @CompTypeNum 
                                  WHEN 0 THEN 'NONE' 
                                  WHEN 1 THEN 'ROW'
                                  WHEN 2 THEN 'PAGE' 
                                  END;
    
        DELETE FROM @ProcResult;

        RAISERROR('Estimating compression savings using "%s" compression for object "%s.%s", index "%s", partition %d...', 10, 1, @CompressionType, @SchemaName, @ObjectName, @IndexName, @PartitionNum);

        INSERT INTO @ProcResult
        EXEC sp_estimate_data_compression_savings @schema_name = @SchemaName, 
                                                  @object_name = @ObjectName, 
                                                  @index_id = @IndexID, 
                                                  @partition_number = @PartitionNum, 
                                                  @data_compression = @CompressionType;
        
        INSERT INTO @CompressionSavingsEstimate
        (
        SchemaName,
        ObjectName,
        IndexName,
        IndexType,
        PartitionNum,
        CompressionType,
        [size_with_current_compression_setting (KB)],
        [size_with_requested_compression_setting (KB)],
        [sample_size_with_current_compression_setting (KB)],
        [sample_size_with_requested_compression_setting (KB)]
        )
        SELECT [schema_name],
               [object_name],
               @IndexName,
               @IndexType,
               [partition_number],
               @CompressionType,
               [size_with_current_compression_setting (KB)],
               [size_with_requested_compression_setting (KB)],
               [sample_size_with_current_compression_setting (KB)],
               [sample_size_with_requested_compression_setting (KB)]
        FROM @ProcResult;
        
        SELECT @CompTypeNum += 1;
    END;
END;

CLOSE CompressedIndex;
DEALLOCATE CompressedIndex;

SELECT SchemaName,
       ObjectName,
       IndexName,
       IndexType,
       PartitionNum,
       CompressionType,
       AVG([size_with_current_compression_setting (KB)]) AS [size_with_current_compression_setting (KB)],
       AVG([size_with_requested_compression_setting (KB)]) AS [size_with_requested_compression_setting (KB)],
       AVG([sample_size_with_current_compression_setting (KB)]) AS [sample_size_with_current_compression_setting (KB)],
       AVG([sample_size_with_requested_compression_setting (KB)]) AS [sample_size_with_requested_compression_setting (KB)]
FROM @CompressionSavingsEstimate
GROUP BY GROUPING SETS (
                       (CompressionType),
                       (SchemaName, ObjectName, IndexName, IndexType, PartitionNum, CompressionType)
                       )
ORDER BY SchemaName, ObjectName, IndexName, IndexType, PartitionNum, CompressionType DESC;

SET NOCOUNT OFF;