--	https://www.brentozar.com/archive/2017/11/move-tempdb-another-drive-folder/

SELECT 'ALTER DATABASE tempdb MODIFY FILE (NAME = [' + f.name + '],'
	+ ' FILENAME = ''G:\MSSQL15.MSSQLSERVER\Data\' + f.name
	+ CASE WHEN f.type = 1 THEN '.ldf' ELSE '.mdf' END
	+ ''', FILEGROWTH = 1GB);' AS TSQL_MoveFile
	
	,
	'USE [tempdb];
DBCC SHRINKFILE (N'''+cast(f.name as varchar(255))+''' , 20480)
GO
' AS TSQL_SHRINKFILE
FROM sys.master_files f
WHERE f.database_id = DB_ID(N'tempdb');

/*
USE [tempdb]
GO
DBCC SHRINKFILE (N'tempdev' , 20480)
GO
USE [master]
GO
ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'tempdev', FILEGROWTH = 1048576KB )
GO
ALTER DATABASE [tempdb] ADD FILE ( NAME = N'tempdev4', FILENAME = N'G:\MSSQL15.MSSQLSERVER\Data\tempdb4.mdf' , SIZE = 20971520KB , FILEGROWTH = 1048576KB )
GO

*/