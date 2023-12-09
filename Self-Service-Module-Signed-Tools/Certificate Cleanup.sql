USE master
go

DROP PROCEDURE [sp_WhoIsActive]; 
GO
DROP PROCEDURE [sp_kill]
GO
DROP PROCEDURE [sp_WhatIsRunning]
GO
DROP USER [CodeSigningLogin]; 
GO 
DROP LOGIN [CodeSigningLogin]; 
GO 
DROP CERTIFICATE [CodeSigningCertificate]; 
GO

SELECT [Srv Name] = @@servername,
		[DB Name] = DB_NAME(),
		[Object Name] = object_name(cp.major_id),
       [Object Type] = obj.type_desc,   
       [Cert/Key] = coalesce(c.name, a.name),
       cp.crypt_type_desc
FROM   sys.crypt_properties cp
INNER JOIN sys.objects obj        ON obj.object_id = cp.major_id
LEFT   JOIN sys.certificates c    ON c.thumbprint = cp.thumbprint
LEFT   JOIN sys.asymmetric_keys a ON a.thumbprint = cp.thumbprint
ORDER BY [Object Name] ASC
GO

USE DBA
go
DROP PROCEDURE dbo.usp_WhoIsActive_Blocking
GO
DROP USER [CodeSigningLogin]; 
GO 
DROP CERTIFICATE [CodeSigningCertificate]; 
GO

SELECT [Srv Name] = @@servername,
		[DB Name] = DB_NAME(),
		[Object Name] = object_name(cp.major_id),
       [Object Type] = obj.type_desc,   
       [Cert/Key] = coalesce(c.name, a.name),
       cp.crypt_type_desc
FROM   sys.crypt_properties cp
INNER JOIN sys.objects obj        ON obj.object_id = cp.major_id
LEFT   JOIN sys.certificates c    ON c.thumbprint = cp.thumbprint
LEFT   JOIN sys.asymmetric_keys a ON a.thumbprint = cp.thumbprint
ORDER BY [Object Name] ASC
GO