USE master;
GO

-- https://social.msdn.microsoft.com/Forums/sqlserver/en-US/5f6ea171-f022-4537-bd60-c0e21cf1b85f/capture-a-quottruncate-tablequot-action?forum=ssdt

-- exec sp_helpdb 'DBA'
-- select distinct left(physical_name,3) from sys.master_files;
-- exec xp_create_subdir N'D:\Database_Audit\'


CREATE SERVER AUDIT Capture_TRUNCATE
TO FILE
(
 FILEPATH = 'T:\Database_Audit',
 MAXSIZE = 5120 MB,
 MAX_ROLLOVER_FILES=4,
 RESERVE_DISK_SPACE = OFF
)
WITH (QUEUE_DELAY = 5000)
GO
ALTER SERVER AUDIT Capture_TRUNCATE WITH( STATE = ON)
GO

/*
CREATE SERVER AUDIT SPECIFICATION Capture_TRUNCATE
FOR SERVER AUDIT Capture_TRUNCATE
ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP),
ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP),
ADD (DATABASE_PERMISSION_CHANGE_GROUP),
ADD (DATABASE_OBJECT_PERMISSION_CHANGE_GROUP),
ADD (SERVER_PERMISSION_CHANGE_GROUP),
ADD (DATABASE_CHANGE_GROUP),
ADD (DATABASE_OBJECT_CHANGE_GROUP)
ADD (SCHEMA_OBJECT_CHANGE_GROUP)
ADD (SERVER_OBJECT_CHANGE_GROUP),
ADD (SERVER_PRINCIPAL_CHANGE_GROUP)
WITH (STATE = ON)
GO
*/

USE [Facebook]
GO

CREATE DATABASE AUDIT SPECIFICATION Capture_TRUNCATE
FOR SERVER AUDIT Capture_TRUNCATE
--ADD (DATABASE_CHANGE_GROUP),
--ADD (DATABASE_OBJECT_CHANGE_GROUP),
ADD (SCHEMA_OBJECT_CHANGE_GROUP) /* For TRUNCATE */
WITH (STATE = ON)
GO

/*
CREATE DATABASE AUDIT SPECIFICATION [SqlAgentObjectAccess_Audit_MSDB]
FOR SERVER AUDIT [UserServerAudit]
ADD (EXECUTE ON OBJECT::[dbo].[sp_delete_job] BY [dbo]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_delete_job] BY [SQLAgentUserRole]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_add_job] BY [dbo]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_add_job] BY [SQLAgentUserRole])
WITH (STATE = ON)
GO

create database audit specification audit_dba
for server audit audit_dba
add (UPDATE, DELETE ON dbo.WhoIsActive_Staging by public),
add (UPDATE, DELETE ON dbo.WhoIsActive_Staging by public)
WITH (STATE = ON)
go
*/

--CREATE VIEW [dbo].[UserAudit_vw]
--AS
SELECT
	[EventDateLocal] = DATEADD(hh,DATEDIFF(hh,GETUTCDATE(), GETDATE()),aud.event_time), 
	aud.server_instance_name,
	ActionName = CASE WHEN act.action_id IS NULL THEN act2.name ELSE act.[name] END,
	cm.class_type_desc,
	aud.database_name,
	aud.schema_name,
	aud.object_name,
	aud.statement,
	additional_information = CAST(aud.additional_information AS XML),
	aud.session_server_principal_name,
	aud.server_principal_name,
	aud.database_principal_name,
	aud.target_server_principal_name,
	aud.target_database_principal_name,
	aud.file_name,
	aud.audit_file_offset,
	aud.sequence_number,
	aud.succeeded,
	aud.session_id
	--,aud.*
FROM sys.fn_get_audit_file ('D:\\MSSQL15.MSSQLSERVER\\MSSQL\audit\Capture_TRUNCATE*',default,default) aud
	INNER JOIN sys.dm_audit_class_type_map cm
		ON cm.class_type = aud.class_type
	LEFT OUTER JOIN sys.dm_audit_actions act
		ON act.action_id = aud.action_id
			AND act.class_desc = cm.securable_class_desc
	LEFT OUTER JOIN sys.dm_audit_actions act2
		ON act2.action_id = aud.action_id
			AND act2.class_desc = cm.class_type_desc
WHERE aud.class_type <> 'A'
go

