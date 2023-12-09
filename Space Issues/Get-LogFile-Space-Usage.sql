--use master;
--select d.name, d.log_reuse_wait_desc from sys.databases as d where d.name = 'Data_Import'
--go

--dbcc sqlperf(logspace)
--go

use ShrinkTest;
select db_name() as dbName, RTRIM(name) AS [Segment Name], f.name, f.physical_name,
   CAST(size/128.0 AS DECIMAL(10,2)) AS [Allocated Size in MB],
   CAST(FILEPROPERTY(name, 'SpaceUsed')/128.0 AS DECIMAL(10,2)) AS [Space Used in MB],
   CAST(size/128.0-(FILEPROPERTY(name, 'SpaceUsed')/128.0) AS DECIMAL(10,2)) AS [Available Space in MB],
   CAST((CAST(FILEPROPERTY(name, 'SpaceUsed')/128.0 AS DECIMAL(10,2))/CAST(size/128.0 AS DECIMAL(10,2)))*100 AS DECIMAL(10,2)) AS [Percent Used]
from sys.database_files f 
--where f.type_desc = 'LOG'
