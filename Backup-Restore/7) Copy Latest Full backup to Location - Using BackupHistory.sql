/* Created By:	AJAY DWIVEDI
    Inputs:	3
*/
SET NOCOUNT ON;
DECLARE
       @BasePath varchar(1000)
       ,@BasePath_Target varchar(1000)
       ,@Path_Target varchar(1000)
      ,@Path varchar(1000)
      ,@FullPath varchar(2000)
      ,@DBName varchar(200)
      ,@Id int
      ,@RecordCount int
	  ,@Counter int
	  ,@BackupFile VARCHAR(2000)
	  ,@BatchCount int
	  ,@BatchCounter int;

--1) Specify existing backup path
SET @BasePath = '\\DC\Backups\SQL-A.Contso.com\MSSQLSERVER';
--2) Specify new backup path
SET @BasePath_Target = 'F:\Backups';
--3) Specify no of batches required
SET	@BatchCount = 2;

DECLARE	@BackupTable TABLE(
		ID INT
		,database_name varchar(200)
		,physical_device_name varchar(2000)
		,size_in_mb bigint
		,batch int
)	 

PRINT	'/*	**********************************************************************************
**********************************************************************************
****************** CMD SCRIPT TO Copy Backps To NEW BACKUP LOCATION **********
			NOTE: Execute below script on Command Prompt
********************************************************************************** */';
-- Get Backup History for required database
 ;WITH T1 AS (
 SELECT 
	ROW_NUMBER()OVER(PARTITION BY s.database_name ORDER BY backup_start_date DESC) as ID,
 s.database_name,
 m.physical_device_name,
 CAST(CAST(s.backup_size / 1000000 AS INT) AS BIGINT)  AS bkSize,
 CAST(DATEDIFF(second, s.backup_start_date,
 s.backup_finish_date) AS VARCHAR(4)) + ' ' + 'Seconds' TimeTaken,
 s.backup_start_date,
 CAST(s.first_lsn AS VARCHAR(50)) AS first_lsn,
 CAST(s.last_lsn AS VARCHAR(50)) AS last_lsn,
 CASE s.[type]
 WHEN 'D' THEN 'Full'
 WHEN 'I' THEN 'Differential'
 WHEN 'L' THEN 'Transaction Log'
 END AS BackupType,
 s.server_name,
 s.recovery_model
 FROM msdb.dbo.backupset s
 INNER JOIN msdb.dbo.backupmediafamily m ON s.media_set_id = m.media_set_id
 WHERE s.database_name not in ('master','model','msdb')
 AND	(CASE s.[type]
 WHEN 'D' THEN 'Full'
 WHEN 'I' THEN 'Differential'
 WHEN 'L' THEN 'Transaction Log'
 END ) = 'Full'
 )
INSERT INTO @BackupTable
(ID, database_name, physical_device_name, size_in_mb)
SELECT	ROW_NUMBER()OVER(ORDER BY bkSize desc, database_name) AS ID, 
		database_name, 
		physical_device_name,
		bkSize
FROM	T1 
WHERE	ID = 1 
ORDER BY bkSize desc, database_name;

UPDATE @BackupTable
SET	batch = (CASE ID%@BatchCount WHEN 0 THEN @BatchCount ELSE ID%@BatchCount END)

--SELECT * FROM @BackupTable;
 
SET @BatchCounter = 1;
WHILE (@BatchCounter <= @BatchCount)
BEGIN

		SET @RecordCount = (SELECT COUNT(1) FROM @BackupTable)
		SET @Counter = 1;
		PRINT	'
		
		
';		

		WHILE (@Counter <= @RecordCount)
		BEGIN
			SET NOCOUNT ON;
			SELECT @FullPath=physical_device_name, @DBName=database_name 
			FROM @BackupTable where batch = @BatchCounter AND ID = @Counter
			
			IF @@ROWCOUNT <> 0
			BEGIN
				PRINT	'copy "'+@FullPath+'" "'+@BasePath_Target+'\'+@DBName+'"';
				
				SET @FullPath = @BasePath_Target+'\'+@DBName;
				EXEC master.sys.xp_create_subdir @FullPath;
			END
			
			SET	@Counter = @Counter + 1;
		END	

	SET	@BatchCounter = @BatchCounter + 1;
END
