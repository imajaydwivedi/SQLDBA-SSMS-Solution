USE master;

CREATE SERVER AUDIT audit_DBA_table
TO FILE
(
 FILEPATH = 'E:\audit',
 MAXSIZE = 5120 MB,
 MAX_ROLLOVER_FILES=4,
 RESERVE_DISK_SPACE = OFF
)
WITH (QUEUE_DELAY = 5000, ON_FAILURE = CONTINUE)
GO
ALTER SERVER AUDIT audit_DBA_table WITH( STATE = ON)
GO

USE [DBA]
go
create database audit specification audit_DBA_table
for server audit audit_DBA_table
add (SELECT, INSERT, UPDATE, DELETE ON dbo.some_table by public),
add (SELECT, INSERT, UPDATE, DELETE ON dbo.some_table by public)
WITH (STATE = ON)
go

CREATE DATABASE AUDIT SPECIFICATION audit_DBA_table
FOR SERVER AUDIT audit_DBA_table
ADD (SELECT ON DATABASE::[DBA] BY [public]),
ADD (UPDATE ON DATABASE::[DBA] BY [public]),
ADD (INSERT ON DATABASE::[DBA] BY [public]),
ADD (EXECUTE ON DATABASE::[DBA] BY [public]),
ADD (DELETE ON DATABASE::[DBA] BY [public])
GO