USE [tempdb]
GO

--	Query to find size of Data/Log files for all databases except tempdb
	-- To estimate required size of tempdb database (20% of other dbs)
	-- https://github.com/imajaydwivedi/SQLDBA-SSMS-Solution/tree/master/PowerShell%20Commands/Find-Data-Log-File-Size-Total-Server.sql


--	Find used/free space in Database Files
select f.type_desc, f.name, f.physical_name, (f.size*8.0)/1024 as size_MB, f.max_size, f.growth, 
	CAST(FILEPROPERTY(f.name, 'SpaceUsed') as BIGINT)/128.0/1024 AS SpaceUsed_gb
		,(size/128.0 -CAST(FILEPROPERTY(name,'SpaceUsed') AS INT)/128.0)/1024 AS FreeSpace_GB
from sys.database_files f
--where f.type_desc = 'ROWS'
order by f.type_desc


--	Shrink files until specific size is attained
USE TEMPDB;
go
WHILE EXISTS (select * from sys.database_files f where type_desc = 'ROWS' and ((f.size*8.0)/1024) > 20480.0) -- 20 gb
BEGIN	
	DBCC SHRINKFILE (N'tempdev' , 20480);
	DBCC SHRINKFILE (N'tempdev2' , 20480);
	DBCC SHRINKFILE (N'tempdev3' , 20480);
	
	WAITFOR DELAY '00:00:10';  
END
GO

--	Increase Db file size if required
USE [master]
GO
ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'tempdev3', SIZE = 20480MB )
GO