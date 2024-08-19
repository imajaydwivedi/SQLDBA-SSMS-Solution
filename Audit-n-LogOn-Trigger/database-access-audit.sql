USE [master]
GO

CREATE SERVER AUDIT LoginAudit
TO FILE 
(	FILEPATH = N'E:\SQLServer-Audit'
	,MAXSIZE = 50 MB
	,MAX_ROLLOVER_FILES = 100
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
select	top 1000 
		a.event_time, server_instance_name, a.client_ip, a.application_name, a.host_name,
		a.database_name, a.schema_name, a.object_name, a.action_id, 
		a.session_id, a.class_type, a.session_server_principal_name, a.statement, 
		a.additional_information
from fn_get_audit_file(
	'E:\SQLServer-Audit\LoginAudit_*.sqlaudit'
	,default
	,default
) a
order by event_time desc
