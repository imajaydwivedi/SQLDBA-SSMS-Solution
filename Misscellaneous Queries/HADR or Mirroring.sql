-- 01) Check existance of file/folder
EXECUTE [master].dbo.xp_fileexist @CurrentRootDirectoryPath

-- 02) Check Cluster information. Work on SQL Server 2012 and above
SELECT * FROM sys.dm_hadr_cluster

-- 03) Check if database is part of Log_Shipping
SELECT * FROM msdb.dbo.log_shipping_primary_databases
SELECT * FROM msdb.dbo.log_shipping_secondary_databases

