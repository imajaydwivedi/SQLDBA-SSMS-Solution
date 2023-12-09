-- :CONNECT <Distributor>

-- Where am I?
SELECT  @@SERVERNAME;
GO

-- Is there already a Distributor here?
EXEC sp_get_distributor;
GO

-- Add the distributor
EXEC sp_adddistributor @distributor = @@SERVERNAME, -- Name of Distributor Server
    @password = N'Pa$$w0rd'; 
GO

select * from sys.sysservers

/*

RESTORE DATABASE [ContsoSQLInventory_Ajay] FROM  DISK = N'Your-Backup-File-Path-in-Here'
    WITH RECOVERY
         ,STATS = 3
         ,REPLACE
		 ,MOVE N'ContsoSQLInventory' TO N'F:\MSSQL15.MSSQLSERVER\SQL2016_Data\ContsoSQLInventory_Ajay.mdf'
		 ,MOVE N'ContsoSQLInventory_log' TO N'F:\MSSQL15.MSSQLSERVER\SQL2016_Data\ContsoSQLInventory_Ajay_log.ldf'

GO
*/

-- A few observations:
-- Database name is configurable
-- Keep note of the path for the data and log file
-- Default data file is just 5MBs so consider @data_file_size
EXEC sp_adddistributiondb @database = N'distribution',
    @data_folder = N'F:\MSSQL15.MSSQLSERVER\SQL2016_Data\', @log_folder = N'F:\MSSQL15.MSSQLSERVER\SQL2016_Log\',
    @log_file_size = 2, @min_distretention = 0, @max_distretention = 72,
    @history_retention = 48;
GO

--select * from sys.dm_server_services

-- Configuring a publisher to use the distribution db
USE distribution;
EXEC sp_adddistpublisher @publisher = N'MSI',
    @distribution_db = N'distribution', @security_mode = 1,
    @working_directory = N'\\MSI\Replication\', @thirdparty_flag = 0, -- if SQL and not another product
    @publisher_type = N'MSSQLSERVER';
GO

-- Let's confirm what we created
EXEC sp_get_distributor;

SELECT  is_distributor,
        *
FROM    sys.servers
WHERE   name = 'repl_distributor' AND
        data_source = @@SERVERNAME;
GO

-- Which database is the distributor?
SELECT  name
FROM    sys.databases
WHERE   is_distributor = 1;

-- Specific to the database
EXEC sp_helpdistributiondb;
GO