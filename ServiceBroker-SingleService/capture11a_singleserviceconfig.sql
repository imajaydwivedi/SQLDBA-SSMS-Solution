-- Enable Service Broker and switch to the database
USE master;
GO
IF DB_ID('DBA') IS NOT NULL
BEGIN
	ALTER DATABASE DBA SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE DBA;
END
GO
CREATE DATABASE DBA;
GO
ALTER DATABASE DBA
      SET ENABLE_BROKER;
GO
USE DBA;
GO
-- Create the message types
CREATE MESSAGE TYPE
       [HelloWorldMessage]
       VALIDATION = WELL_FORMED_XML;
GO

-- View the message types we just created
SELECT * 
FROM sys.service_message_types
WHERE message_type_id > 65535;
GO


-- Create the contract
CREATE CONTRACT [HelloWorldContract]
      ([HelloWorldMessage]
       SENT BY INITIATOR);
GO

-- View the contract we created
SELECT *
FROM sys.service_contracts
WHERE service_contract_id > 65535;
GO

-- Create the target queue and service
CREATE QUEUE HelloWorldQueue;
GO
-- Check for our queue
SELECT * 
FROM sys.service_queues
WHERE is_ms_shipped = 0;
GO

CREATE SERVICE
       [HelloWorldService]
       ON QUEUE HelloWorldQueue
       ([HelloWorldContract]);
GO

-- Check our service
SELECT *
FROM sys.services
WHERE service_id > 65535;
GO
