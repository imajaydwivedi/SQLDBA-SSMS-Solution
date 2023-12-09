/*USE <db_name>*/ --Set db name before running using drop-down above or this USE statement
USE dustbin;
SET NOCOUNT ON;

DECLARE @file_name sysname,
@file_size_MB int,
@file_growth int,
@shrink_command nvarchar(max),
@alter_command nvarchar(max)

SET @file_size_MB = 118*1024;

SELECT @file_name = name
FROM sys.database_files
WHERE type_desc = 'log'

SELECT @shrink_command = 'DBCC SHRINKFILE (N''' + @file_name + ''' , 0, TRUNCATEONLY)'
PRINT @shrink_command
EXEC sp_executesql @shrink_command

SELECT @shrink_command = 'DBCC SHRINKFILE (N''' + @file_name + ''' , 0)'
PRINT @shrink_command
EXEC sp_executesql @shrink_command

DECLARE @counter int = 1;
WHILE 1 = 1 
BEGIN
	SET @file_growth = @counter * 8000;
	SELECT @alter_command = 'ALTER DATABASE [' + db_name() + '] MODIFY FILE (NAME = N''' + @file_name + ''', SIZE = ' + CAST(@file_growth AS nvarchar) + 'MB)'
	PRINT @alter_command
	--EXEC sp_executesql @alter_command
	SET @counter = @counter + 1;
	IF (@counter * 8000) > @file_size_MB
		BREAK;
END

PRINT 'USE [master]
GO
'
select 'ALTER DATABASE ['+DB_NAME()+'] MODIFY FILE ( NAME = N'''+df.name+''', SIZE = 7500MB , FILEGROWTH = 0)
GO'
from sys.database_files as df
where df.type_desc = 'ROWS'

