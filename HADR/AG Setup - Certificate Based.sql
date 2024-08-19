:CONNECT AgHost-1A
USE master;  
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'S0meStrongP@ssword';  
GO

USE master; 
--drop certificate AgHost_1A_cert;
CREATE CERTIFICATE AgHost_1A_cert   
   WITH SUBJECT = 'AgHost-1A certificate',
   expiry_date='2032-12-31';  
GO

--drop endpoint Endpoint_Mirroring;
CREATE ENDPOINT Endpoint_Mirroring  
   STATE = STARTED  
   AS TCP (  
      LISTENER_PORT=5022
      , LISTENER_IP = ALL  
   )   
   FOR DATABASE_MIRRORING (   
      AUTHENTICATION = CERTIFICATE AgHost_1A_cert  
      , ENCRYPTION = REQUIRED ALGORITHM AES  
      , ROLE = ALL  
   );  
GO

BACKUP CERTIFICATE AgHost_1A_cert TO FILE = '\\sqlmonitor\Backup\AgHost-1A\AgHost_1A_cert.cer';
GO

USE master;  
CREATE LOGIN remote_host_login WITH PASSWORD = 'S0meStrongP@ssword';  
GO
CREATE USER remote_host_login FOR LOGIN remote_host_login;  
GO

:CONNECT AgHost-1B
USE master;  
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'S0meStrongP@ssword';  
GO

USE master;  
--drop certificate AgHost_1B_cert;
CREATE CERTIFICATE AgHost_1B_cert   
   WITH SUBJECT = 'AgHost-1B certificate',
   expiry_date='2032-12-31';    
GO

--drop endpoint Endpoint_Mirroring;
CREATE ENDPOINT Endpoint_Mirroring  
   STATE = STARTED  
   AS TCP (  
      LISTENER_PORT=5022
      , LISTENER_IP = ALL  
   )   
   FOR DATABASE_MIRRORING (   
      AUTHENTICATION = CERTIFICATE AgHost_1B_cert  
      , ENCRYPTION = REQUIRED ALGORITHM AES  
      , ROLE = ALL  
   );  
GO

BACKUP CERTIFICATE AgHost_1B_cert TO FILE = '\\sqlmonitor\Backup\AgHost-1B\AgHost_1B_cert.cer';
GO

USE master;  
CREATE LOGIN remote_host_login WITH PASSWORD = 'S0meStrongP@ssword';  
GO
CREATE USER remote_host_login FOR LOGIN remote_host_login;  
GO


:CONNECT AgHost-1A
--drop certificate AgHost_1B_cert;
CREATE CERTIFICATE AgHost_1B_cert  
   AUTHORIZATION remote_host_login  
   FROM FILE = '\\sqlmonitor\Backup\AgHost-1B\AgHost_1B_cert.cer'  
GO

GRANT CONNECT ON ENDPOINT::Endpoint_Mirroring TO remote_host_login;
go
GRANT CONNECT ON ENDPOINT::[Endpoint_Mirroring] TO [LAB\SQLService]
GO


:CONNECT AgHost-1B
--drop certificate AgHost_1A_cert;
CREATE CERTIFICATE AgHost_1A_cert  
   AUTHORIZATION remote_host_login  
   FROM FILE = '\\sqlmonitor\Backup\AgHost-1A\AgHost_1A_cert.cer'  
GO

GRANT CONNECT ON ENDPOINT::Endpoint_Mirroring TO remote_host_login;  
GRANT CONNECT ON ENDPOINT::[Endpoint_Mirroring] TO [LAB\SQLService]
GO


:CONNECT AgHost-1A
backup database DBATools to disk = '\\sqlmonitor\Backup\AgHost-1A\DBATools_full.bak'
	with stats = 5
go
backup log DBATools to disk = '\\sqlmonitor\Backup\AgHost-1A\DBATools_log.trn'
	with stats = 5
go



:CONNECT AgHost-1B
go
restore database DBATools from disk = '\\sqlmonitor\Backup\AgHost-1A\DBATools_full.bak'
	with stats = 5, norecovery
go
restore log DBATools from disk = '\\sqlmonitor\Backup\AgHost-1A\DBATools_log.trn'
	with stats = 5, norecovery
go


:Connect AGHOST-1A
USE [master]
GO
CREATE AVAILABILITY GROUP [Ag1]
WITH (AUTOMATED_BACKUP_PREFERENCE = NONE,
DB_FAILOVER = OFF,
DTC_SUPPORT = NONE,
REQUIRED_SYNCHRONIZED_SECONDARIES_TO_COMMIT = 0)
FOR DATABASE [DBATools]
REPLICA ON N'AGHOST-1A' WITH (ENDPOINT_URL = N'TCP://AgHost-1A.Lab.com:5022', FAILOVER_MODE = AUTOMATIC, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, BACKUP_PRIORITY = 50, SEEDING_MODE = MANUAL, SECONDARY_ROLE(ALLOW_CONNECTIONS = ALL)),
	N'AGHOST-1B' WITH (ENDPOINT_URL = N'TCP://AgHost-1B.Lab.com:5022', FAILOVER_MODE = AUTOMATIC, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, BACKUP_PRIORITY = 50, SEEDING_MODE = MANUAL, SECONDARY_ROLE(ALLOW_CONNECTIONS = ALL));
GO


:Connect AGHOST-1A
USE [master]
GO
ALTER AVAILABILITY GROUP [Ag1]
ADD LISTENER N'SqlAg1' (
WITH IP
((N'192.168.100.109', N'255.255.255.0')
)
, PORT=1433);
GO

:Connect AGHOST-1B
ALTER AVAILABILITY GROUP [Ag1] JOIN;
GO


:Connect AGHOST-1B
ALTER DATABASE [DBATools] SET HADR AVAILABILITY GROUP = [Ag1];
GO
