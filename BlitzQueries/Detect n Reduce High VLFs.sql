-- Detecting and reducing VLFs in SQL Server 2008
-- Glenn Berry 
-- June 2010
-- http://glennberrysqlperformance.spaces.live.com/
-- Twitter: GlennAlanBerry

-- Switch to your database
USE DBA;
GO

-- Check VLF Count for current database
DBCC LogInfo;

-- Check individual File Sizes and space available for current database
SELECT name AS [File Name] , physical_name AS [Physical Name], size/128.0 AS [Total Size in MB],
size/128.0 - CAST(FILEPROPERTY(name, 'SpaceUsed') AS int)/128.0 AS [Available Space In MB], [file_id]
FROM sys.database_files;

-- Step 1: Compressed backup of the transaction log (backup compression requires Enterprise Edition in SQL Server 2008)
BACKUP LOG [StackOverflow] TO  DISK = N'N:\SQLBackups\StackOverflowLogBackup.bak' WITH NOFORMAT, INIT,  
NAME = N'StackOverflow- Transaction Log  Backup', SKIP, NOREWIND, NOUNLOAD, COMPRESSION, STATS = 1;
GO



-- Step 2: Shrink the log file
DBCC SHRINKFILE (N'dba_Log' , 0, TRUNCATEONLY);
GO

-- Check VLF Count for current database
DBCC LogInfo;

-- Step 3: Grow the log file back to the desired size, 
-- which depends on the amount of write activity 
-- and how often you do log backups
USE [master];
GO
ALTER DATABASE DBA MODIFY FILE (NAME = N'dba_Log', SIZE = 8GB);
GO

-- Switch back to your database
USE DBA;
GO

-- Check VLF Count for current database after growing log file
DBCC LogInfo;
