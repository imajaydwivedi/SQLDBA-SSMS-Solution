/*	=====================================================================================================================
--	https://learn.microsoft.com/en-us/sql/database-engine/database-mirroring/example-setting-up-database-mirroring-using-certificates-transact-sql?view=sql-server-ver16#ConfiguringOutboundConnections
*/

--	----------------------------------------------
--	To configure Host_A for outbound connections
--------------------------------------------------
-- 1. On the master database, create the database master key, if needed.
USE master;  
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'S4HADNXamyOXVGf';  
GO

-- 2. Make a certificate for this server instance.
USE master;  
CREATE CERTIFICATE HOST_A_cert   
   WITH SUBJECT = 'HOST_A certificate';  
GO

-- 3. Create a mirroring endpoint for server instance using the certificate.
CREATE ENDPOINT Endpoint_Mirroring  
   STATE = STARTED  
   AS TCP (  
      LISTENER_PORT=7024  
      , LISTENER_IP = ALL  
   )   
   FOR DATABASE_MIRRORING (   
      AUTHENTICATION = CERTIFICATE HOST_A_cert  
      , ENCRYPTION = REQUIRED ALGORITHM AES  
      , ROLE = ALL  
   );  
GO

-- 4. Back up the HOST_A certificate, and copy it to other system, HOST_B.
BACKUP CERTIFICATE HOST_A_cert TO FILE = 'C:\HOST_A_cert.cer';  
GO


--	----------------------------------------------
--	To configure Host_B for outbound connections
--------------------------------------------------
-- 1. On the master database, create the database master key, if needed.
USE master;  
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '<1_Strong_Password!>';  
GO

-- 2. Make a certificate for this server instance.
USE master;  
CREATE CERTIFICATE HOST_A_cert   
   WITH SUBJECT = 'HOST_A certificate';  
GO

-- 3. Create a mirroring endpoint for server instance using the certificate.
CREATE ENDPOINT Endpoint_Mirroring  
   STATE = STARTED  
   AS TCP (  
      LISTENER_PORT=7024  
      , LISTENER_IP = ALL  
   )   
   FOR DATABASE_MIRRORING (   
      AUTHENTICATION = CERTIFICATE HOST_A_cert  
      , ENCRYPTION = REQUIRED ALGORITHM AES  
      , ROLE = ALL  
   );  
GO

-- 4. Back up the HOST_A certificate, and copy it to other system, HOST_B.
BACKUP CERTIFICATE HOST_A_cert TO FILE = 'C:\HOST_A_cert.cer';  
GO
