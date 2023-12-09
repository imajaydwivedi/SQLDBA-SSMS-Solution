-- If Size of Log file is greator than 200 gb, then try to truncate it
USE TEMPDB;
WHILE EXISTS (select mf.name, mf.physical_name, size_gb = (size*8.0/1024/1024) from sys.master_files as mf where mf.database_id = db_id('tempdb') and type_desc = 'LOG' and (size*8.0/1024/1024) > 200.0)
BEGIN
	
	DBCC SHRINKFILE (N'templog' , 0, TRUNCATEONLY);
	WAITFOR DELAY '00:05';  
END
GO