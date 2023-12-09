--	Minimum permissions required to run sp_Blitz
	-- https://dba.stackexchange.com/a/188193/98923
--	Certificate Signing Stored Procedures in Multiple Databases
	-- https://www.sqlskills.com/blogs/jonathan/certificate-signing-stored-procedures-in-multiple-databases/

USE master
GO

CREATE CERTIFICATE [CodeSigningCertificate]	ENCRYPTION BY PASSWORD = 'Some' WITH EXPIRY_DATE = '2099-01-01' ,SUBJECT = 'DBA Code Signing Cert'
GO

BACKUP CERTIFICATE [CodeSigningCertificate] TO FILE = 'C:\temp\CodeSigningCertificate.cer'
	WITH PRIVATE KEY (FILE = 'C:\temp\CodeSigningCertificate_WithKey.pvk', ENCRYPTION BY PASSWORD = '$tr0ngp@$$w0rd', DECRYPTION BY PASSWORD = '$tr0ngp@$$w0rd' );
GO

/*
DECLARE @cmd NVARCHAR(MAX) = 'xp_cmdshell ''del "C:\temp\CodeSigningCertificate.cer"'''; EXEC (@cmd);
SET @cmd = 'xp_cmdshell ''del "C:\temp\CodeSigningCertificate_WithKey.pvk"'''; EXEC (@cmd);
*/

CREATE LOGIN [CodeSigningLogin] FROM CERTIFICATE [CodeSigningCertificate];
GO

GRANT AUTHENTICATE SERVER TO [CodeSigningLogin]
GO

EXEC master..sp_addsrvrolemember @loginame = N'CodeSigningLogin', @rolename = N'sysadmin'
GO

USE DBA
GO

CREATE CERTIFICATE [CodeSigningCertificate] FROM FILE = 'C:\temp\CodeSigningCertificate.cer'
	WITH PRIVATE KEY (FILE = 'C:\temp\CodeSigningCertificate_WithKey.pvk',
					  ENCRYPTION BY PASSWORD = '$tr0ngp@$$w0rd',
					  DECRYPTION BY PASSWORD = '$tr0ngp@$$w0rd'
					  );
GO

--CREATE USER [CodeSigningLogin] FROM LOGIN [CodeSigningLogin]
--GO
CREATE USER [CodeSigningLogin] FROM CERTIFICATE [CodeSigningCertificate];
GO

EXEC sp_addrolemember N'db_owner', N'CodeSigningLogin'
GO

USE master
go

ADD SIGNATURE TO [dbo].[sp_Kill] BY CERTIFICATE [CodeSigningCertificate] WITH PASSWORD = '$tr0ngp@$$w0rd' 
GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_Kill] TO [public]
GO

ADD SIGNATURE TO [dbo].[sp_WhoIsActive] BY CERTIFICATE [CodeSigningCertificate] WITH PASSWORD = '$tr0ngp@$$w0rd' 
GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_WhoIsActive] TO [public]
GO

ADD SIGNATURE TO [dbo].[sp_WhatIsRunning] BY CERTIFICATE [CodeSigningCertificate] WITH PASSWORD = '$tr0ngp@$$w0rd' 
GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_WhatIsRunning] TO [public]
GO

USE DBA
GO
GRANT CONNECT TO [public]
GO

GRANT CONNECT TO [guest]
GO

ADD SIGNATURE TO [dbo].[usp_WhoIsActive_Blocking] BY CERTIFICATE [CodeSigningCertificate] WITH PASSWORD = '$tr0ngp@$$w0rd' 
GO

GRANT EXECUTE ON OBJECT::[dbo].[usp_WhoIsActive_Blocking] TO [public]
GO

/*
SELECT [Object Name] = object_name(cp.major_id),
       [Object Type] = obj.type_desc,   
       [Cert/Key] = coalesce(c.name, a.name),
       cp.crypt_type_desc
FROM   sys.crypt_properties cp
INNER JOIN sys.objects obj        ON obj.object_id = cp.major_id
LEFT   JOIN sys.certificates c    ON c.thumbprint = cp.thumbprint
LEFT   JOIN sys.asymmetric_keys a ON a.thumbprint = cp.thumbprint
ORDER BY [Object Name] ASC

*/