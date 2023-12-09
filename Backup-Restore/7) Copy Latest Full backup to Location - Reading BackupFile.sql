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
SET @BasePath = 'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Backup';
--2) Specify new backup path
SET @BasePath_Target = 'C:\Migration';
--3) Specify no of batches required
SET	@BatchCount = 2;

DECLARE	@BackupTable TABLE(
		ID INT
		,database_name varchar(200)
		,physical_device_name varchar(2000)
		,size_in_mb bigint
		,batch int
)


DECLARE @DirectoryTree TABLE(
       id int IDENTITY(1,1)
      ,fullpath varchar(2000)
      ,subdirectory nvarchar(512)
      ,depth int);

DECLARE @BackupFileList TABLE(
       id int IDENTITY(1,1)
      ,fullpath varchar(2000)
      ,subdirectory nvarchar(512)
      ,depth int
	  ,isFile int
	  ,isLatestOnDate int default 0
	  ,BackupDate DATETIME2);

DECLARE @backupmediafamily TABLE (
	database_name varchar(256),
	physical_device_name varchar(2000),
	bkSize BIGINT,
	TimeTaken varchar(200),
	backup_start_date datetime2,
	BackupType varchar(200),
	server_name varchar(500),
	recovery_model varchar(200))

CREATE TABLE #headers
( BackupName varchar(256), BackupDescription varchar(256), BackupType varchar(256), 
ExpirationDate varchar(256), Compressed varchar(256), Position varchar(256), DeviceType varchar(256), 
UserName varchar(256), ServerName varchar(256), DatabaseName varchar(256), DatabaseVersion varchar(256), 
DatabaseCreationDate varchar(256), BackupSize varchar(256), FirstLSN varchar(256), LastLSN varchar(256), 
CheckpointLSN varchar(256), DatabaseBackupLSN varchar(256), BackupStartDate varchar(256), BackupFinishDate datetime2, 
SortOrder varchar(256), CodePage varchar(256), UnicodeLocaleId varchar(256), UnicodeComparisonStyle varchar(256), 
CompatibilityLevel varchar(256), SoftwareVendorId varchar(256), SoftwareVersionMajor varchar(256), 
SoftwareVersionMinor varchar(256), SoftwareVersionBuild varchar(256), MachineName varchar(256), Flags varchar(256), 
BindingID varchar(256), RecoveryForkID varchar(256), Collation varchar(256), FamilyGUID varchar(256), 
HasBulkLoggedData varchar(256), IsSnapshot varchar(256), IsReadOnly varchar(256), IsSingleUser varchar(256), 
HasBackupChecksums varchar(256), IsDamaged varchar(256), BeginsLogChain varchar(256), HasIncompleteMetaData varchar(256), 
IsForceOffline varchar(256), IsCopyOnly varchar(256), FirstRecoveryForkID varchar(256), ForkPointLSN varchar(256), 
RecoveryModel varchar(256), DifferentialBaseLSN varchar(256), DifferentialBaseGUID varchar(256), 
BackupTypeDescription varchar(256), BackupSetGUID varchar(256), CompressedBackupSize varchar(256), 
Containment varchar(256) ); 

-- Drop Containment column from #headers for SQL Server 2008 R2
IF (SELECT CONVERT(VARCHAR(50),SERVERPROPERTY('productversion'))) LIKE '10.50.%'
BEGIN
	ALTER TABLE #headers
		DROP COLUMN Containment;
END

--Populate the table using the initial base path.
INSERT @DirectoryTree (subdirectory,depth) EXEC master.sys.xp_dirtree @BasePath,1,0;
UPDATE @DirectoryTree SET fullpath = @BasePath + '\' + subdirectory;

--SELECT * FROM @DirectoryTree

--Loop through the table as long as there are still folders to process.
WHILE EXISTS (SELECT id FROM @DirectoryTree)
BEGIN

	SELECT TOP (1) @Id = id, @BasePath = fullpath FROM @DirectoryTree;
	
	--Get backup files inside folder
	INSERT @BackupFileList (subdirectory,depth, isFile) EXEC master.sys.xp_dirtree @BasePath,1,1;	
	UPDATE @BackupFileList SET fullpath = @BasePath + '\' + subdirectory;
	
--*****************************************************************************************
--BEGIN:	Loop through each Backup File to get BackupDates
--*****************************************************************************************
	DECLARE BackupFile_cursor CURSOR FOR 
		SELECT fullpath FROM @BackupFileList ORDER BY fullpath;

	OPEN BackupFile_cursor
	FETCH NEXT FROM BackupFile_cursor INTO @BackupFile;

	SET	@Counter = 1;
	WHILE (@Counter <= (SELECT COUNT(fullpath) FROM @BackupFileList))
	BEGIN
		BEGIN TRY
			INSERT INTO #headers
			EXEC ('restore headeronly from disk = '''+ @BackupFile + '''');
		
			UPDATE @BackupFileList
			SET	BackupDate = (SELECT TOP (1) BackupFinishDate FROM #headers)		
			WHERE fullpath = @BackupFile;

			INSERT INTO @backupmediafamily
			(
				database_name,
				physical_device_name,
				bkSize,
				TimeTaken,
				backup_start_date,
				BackupType,
				server_name,
				recovery_model
			)
			SELECT	DatabaseName, @BackupFile, BackupSize, DATEDIFF(S,BackupStartDate,BackupFinishDate) as TimeTaken, BackupStartDate, 
					(case BackupType when 1 then 'Full'
									when 5 then 'Differential'
									when 2 then 'Transaction Log'
									else 'Inappropriate'
									end) as BackupType,
					ServerName, RecoveryModel
			FROM	#headers

			DELETE FROM #headers;
		END TRY
		BEGIN CATCH 
			PRINT '/* Error Occurred:
Database file '''+@BackupFile+''' seems corrupt.
*/';
		END CATCH
		SET	@Counter = @Counter + 1;
	FETCH NEXT FROM BackupFile_cursor INTO @BackupFile;
	END

	CLOSE BackupFile_cursor 
	DEALLOCATE BackupFile_cursor 
--*****************************************************************************************
--END:	Loop through each Backup File to get BackupDates
--*****************************************************************************************

    DELETE FROM @DirectoryTree WHERE id = @Id;
	DELETE FROM @BackupFileList;
END;

DROP TABLE #headers;

--select * from @backupmediafamily;
PRINT	'/*	**********************************************************************************
**********************************************************************************
****************** CMD SCRIPT TO Copy Backps To NEW BACKUP LOCATION **********
			NOTE: Execute below script on Command Prompt
********************************************************************************** */';
-- Get Backup History for required database
 ;WITH T1 AS (
 SELECT 
	ROW_NUMBER()OVER(PARTITION BY database_name ORDER BY backup_start_date DESC) as ID,
	*
 FROM @backupmediafamily
 WHERE database_name not in ('master','model','msdb')
 AND	BackupType = 'Full'
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

/*
SELECT CAST(value AS TINYINT) FROM sys.configurations WHERE name = 'xp_cmdshell'

-- To allow advanced options to be changed.
EXEC sp_configure 'show advanced options', 1;
GO
-- To update the currently configured value for advanced options.
RECONFIGURE;
GO
-- To disable the feature.
EXEC sp_configure 'xp_cmdshell', 1;
GO
-- To update the currently configured value for this feature.
RECONFIGURE;
GO

EXEC xp_cmdshell 'copy "C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Backup\Recovery\facebook_backup_2015_12_08_220001_5813963.bak" "C:\Migration\facebook"';
GO
*/