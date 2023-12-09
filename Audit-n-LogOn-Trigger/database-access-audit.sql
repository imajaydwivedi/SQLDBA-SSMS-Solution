USE [master]
GO

CREATE SERVER AUDIT LoginAudit
TO FILE 
(	FILEPATH = N'E:\LoginAudit'
	,MAXSIZE = 50 MB
	,MAX_ROLLOVER_FILES = 10
	,RESERVE_DISK_SPACE = OFF
) 
WITH
(	QUEUE_DELAY = 1000
	,ON_FAILURE = CONTINUE
)
GO

-- Enable the server audit.  
ALTER SERVER AUDIT LoginAudit   
WITH (STATE = ON) ;  
GO

USE [DBA]
GO

CREATE DATABASE AUDIT SPECIFICATION LoginAudit
FOR SERVER AUDIT LoginAudit
ADD (SCHEMA_OBJECT_ACCESS_GROUP)
WITH (STATE = ON)
GO


-- Read audit file
select top 1000 * from fn_get_audit_file(
	'E:\LoginAudit\LoginAudit_*.sqlaudit'
	,default
	,default
)
order by event_time desc
