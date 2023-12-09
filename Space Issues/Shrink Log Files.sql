exec sp_WhatIsRunning 1
exec sp_WhatIsRunning 5
--exec sp_WhatIsRunning 3

select d.name, d.log_reuse_wait_desc from sys.databases as d
SELECT db_name(database_id) as dbName, ((mf.size * 8.0)/1024)/1024 as size_GB
FROM sys.master_files mf  where (mf.size * 8)/1024 >= 5000 and type_desc = 'LOG'


SELECT '
USE ['+db_name(database_id)+']
GO
PRINT ''-- ['+db_name(database_id)+']''
DBCC OPENTRAN([rtcab])
GO
DBCC SHRINKFILE (N'''+name+''' , truncateonly)
DBCC SHRINKFILE (N'''+name+''' , 0)
GO
'
FROM sys.master_files mf  where (mf.size * 8)/1024 >= 5000 and type_desc = 'LOG'