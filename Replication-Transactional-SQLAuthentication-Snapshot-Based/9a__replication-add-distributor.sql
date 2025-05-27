-- :CONNECT <Distributor>

-- Where am I?
SELECT  @@SERVERNAME;
GO

-- Is there already a Distributor here?
EXEC sp_get_distributor;
GO

use master
go
-- Add the distributor
  -- Execute on [PublisherServer] and [DistributorServer] servers
EXEC sp_adddistributor 
				@distributor = '<DistributorServerNameHere>',
				--@distributor = @@SERVERNAME, -- Name of Distributor Server
				@password = N'<ReplLoginPasswordHere>'; 
GO

select * from sys.sysservers
go

-- A few observations:
-- Database name is configurable
-- Keep note of the path for the data and log file
-- Default data file is just 5MBs so consider @data_file_size
  -- Execute on [DistributorServer]
EXEC sp_adddistributiondb @database = N'<DistributionDbNameHere>',
    @data_folder = N'E:\Data\', @log_folder = N'E:\Log\',
    @log_file_size = 2048, @min_distretention = 0, @max_distretention = 72,
    @history_retention = 48;
GO

--select * from sys.dm_server_services

-- Configuring a publisher to use the distribution db
  -- Execute on [DistributorServer] for each Publisher Server
use [<DistributionDbNameHere>];
EXEC sp_adddistpublisher @publisher = N'<PublisherServerNameHere>',
    @distribution_db = N'<DistributionDbNameHere>', @security_mode = 0,
	@login = 'sa', @password = '<ReplLoginPasswordHere>',
    @working_directory = N'\\SqlMonitor\Backup\ReplData\', @thirdparty_flag = 0, -- if SQL and not another product
    @publisher_type = N'MSSQLSERVER';
GO


-- Let's confirm what we created
  -- Execute on [DistributorServer]
EXEC sp_get_distributor;

  -- Execute on [DistributorServer]
SELECT  is_distributor,
        *
FROM    sys.servers
WHERE   name = 'repl_distributor' AND
        data_source = @@SERVERNAME;
GO

-- Which database is the distributor?
  -- Execute on [DistributorServer]
SELECT  name
FROM    sys.databases
WHERE   is_distributor = 1;

-- Specific to the database
  -- Execute on [DistributorServer]
EXEC sp_helpdistributiondb;
GO

