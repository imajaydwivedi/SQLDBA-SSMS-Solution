--RCM and Srpingbatch_association______
DECLARE @myScript VARCHAR(8000);

;WITH tUsers as
(
SELECT	'
USE [master]
GO
CREATE LOGIN ['+myUser+'] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
GO
USE [StackOverflow]
GO
CREATE USER ['+myUser+'] FOR LOGIN ['+myUser+']
GO
USE [Youtube_20130710_AudioMusic]
GO
EXEC sp_addrolemember N''db_datareader'', N'''+myUser+'''
GO

' as script
FROM (VALUES 
('contso\Login01')
,('contso\Login02')
,('contso\Login03'	   )
,('contso\Login04')) as Users(myUser)
)
select script as [text()]
from tUsers for xml path('')


