EXEC master..sp_WhatIsRunning
go

EXEC master..sp_WhoIsActive
GO

EXEC DBA..usp_WhoIsActive_Blocking
GO

EXEC master..sp_kill @p_spid = 74 --,@p_verbose =1
GO


select top 10 * from DBA..whoisactive_resultsets