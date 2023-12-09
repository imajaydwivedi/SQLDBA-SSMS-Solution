USE master;  
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'S0meStrongP@ssword';  
GO

USE master;  
CREATE CERTIFICATE SqlHost_E_cert   
   WITH SUBJECT = 'SqlHost-E certificate';  
GO

CREATE ENDPOINT Endpoint_Mirroring  
   STATE = STARTED  
   AS TCP (  
      LISTENER_PORT=5022
      , LISTENER_IP = ALL  
   )   
   FOR DATABASE_MIRRORING (   
      AUTHENTICATION = CERTIFICATE SqlHost_E_cert  
      , ENCRYPTION = REQUIRED ALGORITHM AES  
      , ROLE = ALL  
   );  
GO

BACKUP CERTIFICATE SqlHost_E_cert TO FILE = 'C:\SqlHost_E_cert.cer';  
GO

USE master;  
CREATE LOGIN mirror_host_login WITH PASSWORD = 'S0meStrongP@ssword';  
GO
CREATE USER mirror_host_login FOR LOGIN mirror_host_login;  
GO

CREATE CERTIFICATE MirrorCluster_cert  
   AUTHORIZATION mirror_host_login  
   FROM FILE = '\\SqlHost-C\C$\MirrorCluster_cert.cer'  
GO

GRANT CONNECT ON ENDPOINT::Endpoint_Mirroring TO mirror_host_login;  
GO

/*
--alter database DBATools set recovery full
go
backup database DBATools to disk = '\\SQLMONITOR\Backup\MirrorCluster\DBATools_full.bak'
	with stats = 5
go
backup log DBATools to disk = '\\SQLMONITOR\Backup\MirrorCluster\DBATools_log.trn'
	with stats = 5
go

ALTER DATABASE DBATools   
    SET PARTNER = 'TCP://192.168.200.18:5022';  
GO

--Change to high-performance mode by turning off transacton safety.  
ALTER DATABASE DBATools   
    SET PARTNER SAFETY OFF  
GO

*/