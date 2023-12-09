SELECT	coalesce(db17.dbName,db14.dbName) as dbName, coalesce(db17.name, db14.name) as tableName, 
		[row_count(db17)] = db17.row_count,
		[row_count(db14)] = db14.row_count
		,[row_count(diff)] = isnull(db17.row_count,0)-isnull(db14.row_count,0)
FROM OPENROWSET('SQLNCLI', 'Server=Server01;Database=StackOverflow;Trusted_Connection=yes;',  
     'SELECT [srvName] = @@SERVERNAME, [dbName] = DB_NAME(), o.name,  ddps.row_count FROM sys.indexes AS i INNER JOIN sys.objects AS o ON i.OBJECT_ID = o.OBJECT_ID INNER JOIN sys.dm_db_partition_stats AS ddps ON i.OBJECT_ID = ddps.OBJECT_ID AND i.index_id = ddps.index_id WHERE i.index_id < 2  AND o.is_ms_shipped = 0 ORDER BY row_count desc;') AS db14
full outer join
	(
	SELECT [srvName] = @@SERVERNAME, [dbName] = DB_NAME(), o.name,  ddps.row_count 
FROM sys.indexes AS i
  INNER JOIN sys.objects AS o ON i.OBJECT_ID = o.OBJECT_ID
  INNER JOIN sys.dm_db_partition_stats AS ddps ON i.OBJECT_ID = ddps.OBJECT_ID
  AND i.index_id = ddps.index_id 
	WHERE i.index_id < 2  AND o.is_ms_shipped = 0 --ORDER BY row_count desc
	) as db17
on db17.name = db14.name



--	drop table tempdb..ViewRecordCounts_Staging2
CREATE TABLE tempdb..ViewRecordCounts_Staging2
(
	srvName varchar(125) default @@servername,
	dbName varchar(125) default db_name(),
    table_name varchar(255),
    row_count bigint
)
use StackOverflow;
truncate table tempdb..ViewRecordCounts_Staging2;
select 'insert tempdb..ViewRecordCounts_Staging2 (table_name, row_count)
select [table_name] = '''+(table_schema+'.'+TABLE_NAME)+''', count(1) as row_count from '+quotename(table_schema)+'.'+quotename(TABLE_NAME)+' with (nolock);
go
'
from information_schema.views