-- Query 1 - Getting the Product Version

-- SQL and OS Version information for current instance  (Query 1) (Version Info)
SELECT @@SERVERNAME AS [Server Name], @@VERSION AS [SQL Server and OS Version Info];

-- SQL Server 2014 RTM Branch Builds						
-- Build			Description			Release Date		
-- 11.0.9120        CTP1				6/2/2013
-- 12.0.1524		CTP2				10/15/2013
-- 12.0.2000        RTM					4/1/2014
-- 12.0.2342        CU1                 4/21/2014

-- SQL Server 2014 build versions
-- http://support.microsoft.com/kb/2936603


-- Query 2 - When Was SQL Server Installed 

-- When was SQL Server installed  (Query 2) (SQL Server Install Date)  
SELECT @@SERVERNAME AS [Server Name], create_date AS [SQL Server Install Date] 
FROM sys.server_principals WITH (NOLOCK)
WHERE name = N'NT AUTHORITY\SYSTEM'
OR name = N'NT AUTHORITY\NETWORK SERVICE' OPTION (RECOMPILE);

-- Tells you the date and time that SQL Server was installed
-- It is a good idea to know how old your instance is


-- Get selected server properties (SQL Server 2014)  (Query 3) (Server Properties)
SELECT	SERVERPROPERTY('MachineName') AS [MachineName], SERVERPROPERTY('ServerName') AS [ServerName],  
		SERVERPROPERTY('InstanceName') AS [Instance], SERVERPROPERTY('IsClustered') AS [IsClustered], 
		SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS [ComputerNamePhysicalNetBIOS], 
		SERVERPROPERTY('Edition') AS [Edition], SERVERPROPERTY('ProductLevel') AS [ProductLevel], 
		SERVERPROPERTY('ProductVersion') AS [ProductVersion], SERVERPROPERTY('ProcessID') AS [ProcessID],
		SERVERPROPERTY('Collation') AS [Collation], SERVERPROPERTY('IsFullTextInstalled') AS [IsFullTextInstalled], 
		SERVERPROPERTY('IsIntegratedSecurityOnly') AS [IsIntegratedSecurityOnly],
		SERVERPROPERTY('IsHadrEnabled') AS [IsHadrEnabled], SERVERPROPERTY('HadrManagerStatus') AS [HadrManagerStatus],
		SERVERPROPERTY('IsXTPSupported') AS [IsXTPSupported];


