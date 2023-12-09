USE MSDB
GO

SET NOCOUNT ON;

DECLARE @varDate DATETIME
-- Set date to 30 days ago
SET @varDate = DATEADD(d,-7,GETDATE());
 
DECLARE @r INT;
 
SET @r = 1;
 
WHILE @r > 0
BEGIN
  BEGIN TRANSACTION;
		
	  -- delete from sysmail_attachments
	  DELETE TOP (10000) FROM dbo.sysmail_attachments
	  WHERE Last_mod_date < @varDate;
	 
	  SET @r = @@ROWCOUNT;
 
  COMMIT TRANSACTION;
 
  CHECKPOINT;    -- if simple
  -- BACKUP LOG ... -- if full
END
GO