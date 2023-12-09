TRUNCATE TABLE DBA.dbo.WhoIsActive_ResultSets;
GO
TRUNCATE TABLE DBA..WhoIsActiveCallerDetails
GO


--EXEC msdb..sp_start_job [DBA - Log_With_sp_WhoIsActive]
--go
EXEC msdb..sp_start_job [Log Walk 01]
go
EXEC msdb..sp_start_job [Log Walk 02]
go
EXEC msdb..sp_start_job [Log Walk 03]
go
EXEC msdb..sp_start_job [Log Walk 04]
go
EXEC msdb..sp_start_job [Log Walk 05]
go


SELECT * FROM DBA.dbo.WhoIsActive_ResultSets;
SELECT * FROM DBA.dbo.WhoIsActiveCallerDetails;

/*
SET IMPLICIT_TRANSACTIONS ON;

SELECT * FROM dbo.Users;
*/