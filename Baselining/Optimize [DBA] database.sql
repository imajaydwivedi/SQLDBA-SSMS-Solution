-- 1) Change to Simple recovery model
USE master
GO
ALTER DATABASE [DBA] SET RECOVERY SIMPLE
GO

-- 2) Make sure 'Instant File Initialization' is set on Server


-- 3) Remove High VLF Counts, and set a resonable Log file size
Data file size = 30 gb
	Autogrowth = 1 gb
Log file size = 10 gb
	Autogrowth = 8000 MB


USE [master]
GO
ALTER DATABASE [DBA] MODIFY FILE ( NAME = N'dba_Data', SIZE =  30720MB , FILEGROWTH = 1000MB )
GO
ALTER DATABASE [DBA] MODIFY FILE ( NAME = N'dba_Log', SIZE = 10240MB , FILEGROWTH = 8000MB )
GO
