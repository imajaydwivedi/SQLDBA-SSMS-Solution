USE [master]
GO
/*	Examples:-
EXEC master..[usp_DBAApplyTLogs] 'LSTesting', 'LSTesting', '\\DC\Backups\SQL-A\', @p_TUFLocation = 'E:\LS_UndoFiles' ,@p_Verbose = 1 ,@p_DryRun = 1
EXEC master..[usp_DBAApplyTLogs] 'LSTesting', 'LSTesting', '\\DC\Backups\SQL-A\', @p_TUFLocation = 'E:\LS_UndoFiles'
EXEC master..[usp_DBAApplyTLogs] 'LSTesting', 'LSTesting', '\\DC\Backups\SQL-A\', @p_TUFLocation = 'E:\LS_UndoFiles' ,@p_Verbose = 1
EXEC master..[usp_DBAApplyTLogs] 'LSTesting', 'LSTesting', '\\DC\Backups\SQL-A\', @p_TUFLocation = 'E:\LS_UndoFiles' ,@p_TakeExclusiveLocksForRestore = 1
EXEC master..[usp_DBAApplyTLogs] 'LSTesting', 'LSTesting', '\\DC\Backups\SQL-A\', @p_TUFLocation = 'E:\LS_UndoFiles' ,@p_TakeExclusiveLocksForRestore = 0

--	Run job with Exclusive access Once Every 2 Hours
IF (DATEPART(hour,GETDATE())%2 = 0 
	AND DATEPART(MINUTE,GETDATE()) <= 5
)
BEGIN
	--PRINT 'Even Hours, and 1st 5 minutes'
	EXEC master..[usp_DBAApplyTLogs] 'LSTesting', 'LSTesting', '\\DC\Backups\SQL-A\', @p_TUFLocation = 'E:\LS_UndoFiles' ,@p_TakeExclusiveLocksForRestore = 1
END
ELSE
BEGIN
	--PRINT 'Odd Hours'
	EXEC master..[usp_DBAApplyTLogs] 'LSTesting', 'LSTesting', '\\DC\Backups\SQL-A\', @p_TUFLocation = 'E:\LS_UndoFiles' ,@p_TakeExclusiveLocksForRestore = 0
END
*/

IF OBJECT_ID('dbo.usp_DBAApplyTLogs') IS NULL
	EXEC ('CREATE PROCEDURE [dbo].[usp_DBAApplyTLogs] AS SELECT 1 AS [Dummy];')
GO
ALTER PROCEDURE [dbo].[usp_DBAApplyTLogs]
	@p_SourceDbName VARCHAR(125),		-- Database name on the publisher
	@p_DestinationDbName VARCHAR(125),	-- Database name on the subscriber
	@p_SourceBackupLocation VARCHAR(255), -- Location of the log backup files on the publisher; default Prod
	@p_TUFLocation VARCHAR(100),	-- Location for TUF files on Subscriber
	@p_TakeExclusiveLocksForRestore BIT = 1  -- When set to 1, then procedure will kill any connection on @p_DestinationDbName for Log Restore Activity
	,@p_Verbose INT = 0 -- SET it to 1 to run the procedure in Debugging Mode
	,@p_DryRun INT = 0
AS
BEGIN
/*	Created By:					Ajay Dwivedi
	ModIFied Date:				01-Apr-2018
	Purpose:-					This procedure can be used to restore databases, and will serve AS alternative to 
									default method of log shipping
*/
	--	Declare Local Variables
	SET NOCOUNT ON
	DECLARE @LastFileApplied VARCHAR(255)
	DECLARE @EXECstr VARCHAR(1000)
	DECLARE @Failed INT
	DECLARE @file TABLE (filename VARCHAR(255));
	DECLARE @ID INT ;
	DECLARE @BackupFile VARCHAR(255);
	DECLARE @BackupStartDate SMALLDATETIME;
	DECLARE @backupFiles TABLE (filename VARCHAR(255), BackupStartDate SMALLDATETIME); /* Ajay:- Will contains backups file names along with backup time */
	DECLARE @SuccessfullApply VARCHAR(255);

	DECLARE @LastFullBackupRestoreDate SMALLDATETIME;
	DECLARE @LastRestoredTLogDate SMALLDATETIME;
	DECLARE @LastRestoredTLogFile VARCHAR(255);

	-- Table to store files names from master.sys.dirtree procedure result
	DECLARE @FilesFromPath TABLE( fileName nvarchar(512) ,depth int ,isfile bit);

	IF @p_Verbose = 1
		PRINT	'	Creating #headers file structure';
	IF OBJECT_ID('tempdb..#headers') IS NOT NULL
		DROP TABLE #headers;
	CREATE TABLE #headers
	( BackupName VARCHAR(256), BackupDescription VARCHAR(256), BackupType VARCHAR(256), 
	ExpirationDate VARCHAR(256), Compressed VARCHAR(256), Position VARCHAR(256), DeviceType VARCHAR(256), 
	UserName VARCHAR(256), ServerName VARCHAR(256), DatabaseName VARCHAR(256), DatabaseVersion VARCHAR(256), 
	DatabaseCreationDate VARCHAR(256), BackupSize VARCHAR(256), FirstLSN VARCHAR(256), LastLSN VARCHAR(256), 
	CheckpointLSN VARCHAR(256), DatabaseBackupLSN VARCHAR(256), BackupStartDate VARCHAR(256), BackupFinishDate VARCHAR(256), 
	SortOrder VARCHAR(256), CodePage VARCHAR(256), UnicodeLocaleId VARCHAR(256), UnicodeComparisonStyle VARCHAR(256), 
	CompatibilityLevel VARCHAR(256), SoftwareVENDorId VARCHAR(256), SoftwareVersionMajor VARCHAR(256), 
	SoftwareVersionMinor VARCHAR(256), SoftwareVersionBuild VARCHAR(256), MachineName VARCHAR(256), Flags VARCHAR(256), 
	BindingID VARCHAR(256), RecoveryForkID VARCHAR(256), Collation VARCHAR(256), FamilyGUID VARCHAR(256), 
	HasBulkLoggedData VARCHAR(256), IsSnapshot VARCHAR(256), IsReadOnly VARCHAR(256), IsSingleUser VARCHAR(256), 
	HasBackupChecksums VARCHAR(256), IsDamaged VARCHAR(256), BEGINsLogChain VARCHAR(256), HasIncompleteMetaData VARCHAR(256), 
	IsForceOffline VARCHAR(256), IsCopyOnly VARCHAR(256), FirstRecoveryForkID VARCHAR(256), ForkPoINTLSN VARCHAR(256), 
	RecoveryModel VARCHAR(256), DifferentialBaseLSN VARCHAR(256), DIFferentialBaseGUID VARCHAR(256), 
	BackupTypeDescription VARCHAR(256), BackupSETGUID VARCHAR(256), CompressedBackupSize VARCHAR(256), 
	Containment VARCHAR(256), KeyAlgorithm VARCHAR(100), EncryptorThumbprint VARCHAR(100), EncryptorType VARCHAR(100)); 

	-- Drop Containment column FROM #headers for SQL Server 2008 R2
	IF (SELECT CONVERT(VARCHAR(50),SERVERPROPERTY('productversion'))) LIKE '10.50.%'
	BEGIN
		ALTER TABLE #headers
			DROP COLUMN Containment;
	END
	IF (SELECT CONVERT(VARCHAR(50),SERVERPROPERTY('productversion'))) NOT LIKE '13.%'
	BEGIN
		ALTER TABLE #headers
			DROP COLUMN KeyAlgorithm;
		ALTER TABLE #headers
			DROP COLUMN EncryptorThumbprint;
		ALTER TABLE #headers
			DROP COLUMN EncryptorType;
	END

	SET @Failed = 0;							-- Flag to check IF the last apply was successful or NOT
	IF OBJECT_ID('DBALastFileApplied') IS NULL	--Create table IF it does NOT exist
	BEGIN
		CREATE TABLE DBALastFileApplied
		(
			dbname VARCHAR(125),
			LastFileApplied VARCHAR(255),
			lastUpdateDate datetime default CURRENT_TIMESTAMP
		)
	END

	--	Initiate Local Variables and Tables
	IF RIGHT(RTRIM(@p_SourceBackupLocation),1) <> '\'
	BEGIN
		SET @p_SourceBackupLocation = RTRIM(@p_SourceBackupLocation)+'\';
	END
	IF RIGHT(RTRIM(@p_TUFLocation),1) <> '\'
	BEGIN
		SET @p_TUFLocation = RTRIM(@p_TUFLocation)+'\';
	END

	-- Get the last log file applied
	SELECT	@LastFileApplied = LastFileApplied
	FROM	DBALastFileApplied 
	WHERE	dbname = @p_DestinationDbName;	
	
	--	Check Restore History For Last Full Backup Restore
	SELECT	@LastFullBackupRestoreDate = MAX([rs].[restore_date])
	FROM msdb..restorehistory rs 
	INNER JOIN msdb..backupset bs 
	ON [rs].[backup_set_id] = [bs].[backup_set_id] 
	INNER JOIN msdb..backupmediafamily bmf 
	ON [bs].[media_set_id] = [bmf].[media_set_id] 
	WHERE destination_database_name = @p_DestinationDbName
	AND [bs].[database_name] = @p_SourceDbName
	AND bs.type = 'D';

	--	Check Restore History Of Last TLog Backup
	SELECT	top 1 @LastRestoredTLogDate = [rs].[restore_date]
			,@LastRestoredTLogFile = RIGHT([bmf].[physical_device_name],CHARINDEX('\',REVERSE([bmf].[physical_device_name]))-1)
	FROM msdb..restorehistory rs 
	INNER JOIN msdb..backupset bs 
	ON [rs].[backup_set_id] = [bs].[backup_set_id] 
	INNER JOIN msdb..backupmediafamily bmf 
	ON [bs].[media_set_id] = [bmf].[media_set_id] 
	WHERE destination_database_name = @p_DestinationDbName
	AND [bs].[database_name] = @p_SourceDbName
	AND bs.type = 'L'
	ORDER BY [rs].[restore_date] DESC;

	--	Reset @LastFileApplied according to Restore History of Full Backup and TLog backup
		-- Case when Database refresh is performed
	IF @LastFullBackupRestoreDate IS NOT NULL AND @LastRestoredTLogDate IS NOT NULL
		AND @LastFullBackupRestoreDate >= @LastRestoredTLogDate
	BEGIN
		SET @LastFileApplied = NULL;
		IF @p_Verbose = 1
			PRINT '	IF @LastFullBackupRestoreDate IS NOT NULL AND @LastRestoredTLogDate IS NOT NULL
		AND @LastFullBackupRestoreDate >= @LastRestoredTLogDate';
	END
	ELSE
	IF @LastRestoredTLogDate IS NOT NULL AND @LastFileApplied IS NULL
	BEGIN
		SET @LastFileApplied = @LastRestoredTLogFile;
		IF @p_Verbose = 1
			PRINT '	IF @LastRestoredTLogDate IS NOT NULL AND @LastFileApplied IS NULL';
	END
   
	--Get files using xp_dirtree
	INSERT @FilesFromPath (fileName,depth,isfile) 
		EXEC master.sys.xp_dirtree @p_SourceBackupLocation,0,1;
	DELETE FROM @FilesFromPath WHERE isfile = 0;

	-- Filter out only file names into @file table
	INSERT @file
	SELECT fileName FROM @FilesFromPath;

	IF @p_Verbose = 1
	BEGIN
		PRINT	'	SELECT * FROM @file';
		SELECT	*
		FROM  (	SELECT 'SELECT * FROM @file' AS QueryRunning ) AS Q
		LEFT JOIN
			  ( SELECT * FROM @file ) AS m
			ON	1 = 1
	END

	-- If not files found, then exit
	IF NOT EXISTS (SELECT * FROM @file)
	BEGIN
		PRINT 'No files to process'
		RETURN
	END
	
	IF @p_Verbose = 1
		PRINT	'	Starting to loop through Cursor named [RawBackupFile_cursor] for finding Backup Header Information. ';
	/*	Process each backup file and get header */
	DECLARE RawBackupFile_cursor CURSOR LOCAL FORWARD_ONLY FOR 
		SELECT ROW_NUMBER()OVER(ORDER BY filename) AS id, * FROM @file order by filename;

	OPEN RawBackupFile_cursor
	FETCH NEXT FROM RawBackupFile_cursor INTO @id, @BackupFile;

	WHILE @@FETCH_STATUS = 0 
	BEGIN
		BEGIN TRY
			--	Get Header info. One row per .bak file
			TRUNCATE TABLE #headers;

			INSERT INTO #headers
			EXEC ('restore headeronly FROM disk = '''+@p_SourceBackupLocation+@BackupFile + '''');
			
			IF EXISTS(SELECT * FROM #headers AS h WHERE h.DatabaseName = @p_SourceDbName AND	h.BackupTypeDescription = 'Transaction Log')
			BEGIN
				INSERT @backupFiles 
				(	filename, BackupStartDate	)
				SELECT	@BackupFile, h.BackupStartDate
				FROM	#headers AS h
				WHERE	h.DatabaseName = @p_SourceDbName
					AND	h.BackupTypeDescription = 'Transaction Log';
			END

		END TRY
		BEGIN CATCH
			PRINT '		Some error occurred while reading header of backup file';
			PRINT '		restore headeronly FROM disk = '''+ @p_SourceBackupLocation+@BackupFile + '''';
			PRINT ERROR_MESSAGE();
			PRINT ' -- ---------------------------------------------------------';
		END CATCH
		
		FETCH NEXT FROM RawBackupFile_cursor INTO @id, @BackupFile;
	END

	CLOSE RawBackupFile_cursor;
	DEALLOCATE RawBackupFile_cursor ;
	
	IF @p_Verbose = 1
		PRINT	'Delete all backup file entries FROM @backupFiles table before @LastFileApplied:- '+ISNULL(@LastFileApplied,'NULL');
	IF(@LastFileApplied IS NOT NULL)
		-- Skip files that have already been applied
	BEGIN
		--DELETE FROM @file WHERE filename <= @LastFileApplied
		DELETE FROM @backupFiles
		WHERE (BackupStartDate < (SELECT BackupStartDate FROM @backupFiles AS bi WHERE bi.filename = @LastFileApplied)
			OR [filename] = @LastFileApplied
			);

	END

	IF @p_Verbose = 1
	BEGIN
		PRINT	'	SELECT filename, BackupStartDate FROM @backupFiles order by BackupStartDate';
		SELECT	Q.QueryRunning, m.*
		FROM  (	SELECT 'SELECT filename, BackupStartDate FROM @backupFiles order by BackupStartDate' AS QueryRunning ) AS Q
		LEFT JOIN
			  ( SELECT TOP 1000 filename, BackupStartDate FROM @backupFiles order by BackupStartDate ) AS m
			ON	1 = 1
	END
		
	
	IF @p_Verbose = 1
		PRINT	'	Starting to loop through Cursor named [BackupFile_cursor] inside which we would TRY to RESTORE each log file. ';

	IF EXISTS (SELECT * FROM @backupFiles)
	BEGIN
		/*	Process each backup file and get header */
		DECLARE BackupFile_cursor CURSOR LOCAL FORWARD_ONLY FOR 
					SELECT ROW_NUMBER()OVER(ORDER BY BackupStartDate ASC) AS ID, filename, BackupStartDate 
					FROM @backupFiles order by BackupStartDate;

		OPEN BackupFile_cursor
		FETCH NEXT FROM BackupFile_cursor INTO @id, @BackupFile, @BackupStartDate;

		WHILE @@FETCH_STATUS = 0 
		BEGIN
			--	If restoring the first Log in sequence, then take exclusive access of database
			IF (@id = 1 AND @p_TakeExclusiveLocksForRestore = 1)
			BEGIN
				SET @EXECstr = 'USE master;

	DECLARE @kill varchar(8000); 
	SET @kill = '''';  
	SELECT @kill = @kill + ''kill '' + CONVERT(varchar(5), spid) + '';''
	FROM master..sysprocesses  
	WHERE dbid = '+cast(db_id(@p_DestinationDbName) as varchar(3))+'

	EXEC(@kill); 
	';
				EXEC (@EXECstr);
			END

			SET @EXECstr = 'RESTORE LOG ' + QUOTENAME(@p_DestinationDbName) + ' FROM DISK = ''' + @p_SourceBackupLocation + @BackupFile + ''' WITH NORECOVERY'
		
			BEGIN TRY
				IF @p_DryRun = 0
					EXEC(@EXECstr) -- Apply Transaction logs
				SET @Failed = 0;
				SET @SuccessfullApply = @BackupFile;

				IF @p_Verbose = 1
					PRINT '	Log applied:- '+@BackupFile;
			END TRY
			BEGIN CATCH
				PRINT '--	--------------------------------------------------------';
				PRINT 'Failed on restoring ' + @BackupFile;
				PRINT @EXECstr;
				PRINT ERROR_MESSAGE();
				PRINT '--	--------------------------------------------------------';
				SET @Failed = 1;
			END CATCH

			FETCH NEXT FROM BackupFile_cursor INTO @id, @BackupFile, @BackupStartDate;
		END

		CLOSE BackupFile_cursor;
		DEALLOCATE BackupFile_cursor ;
	
		IF NOT EXISTS(SELECT * FROM DBALastFileApplied WHERE dbname = @p_DestinationDbName) AND @SuccessfullApply IS NOT NULL		-- IF record does NOT exist
		BEGIN
			IF @p_Verbose = 1
				PRINT	'	Creating 1st entry for database '+ QUOTENAME(@p_DestinationDbName)+' INTO table [DBALastFileApplied].';
			IF @p_DryRun = 0
			BEGIN
				INSERT INTO DBALastFileApplied (dbname, LastFileApplied)
				SELECT @p_DestinationDbName AS dbname, [LastFileApplied] = @SuccessfullApply -- create it
			END
		END
	
		IF EXISTS (SELECT * FROM DBALastFileApplied WHERE dbname = @p_DestinationDbName)
		BEGIN
			IF @p_Verbose = 1
				PRINT	'	Updating [LastFileApplied] column value for database '+ QUOTENAME(@p_DestinationDbName)+' INTO table [DBALastFileApplied].';
			-- This update will reSET the LastFileApplied to the last good restore poINT.
			IF @p_DryRun = 0
			BEGIN
				UPDATE DBALastFileApplied 
				SET LastFileApplied = case when @Failed = 0 then @SuccessfullApply ELSE @LastFileApplied END, 
					lastUpdateDate = CURRENT_TIMESTAMP 
				WHERE dbname = @p_DestinationDbName; -- update it
			END
		END	

		IF EXISTS (SELECT Is_In_Standby FROM sys.databases WHERE Name = @p_DestinationDbName AND [State] = 1 AND Is_In_Standby = 0)
		BEGIN							-- SET database in usable (Read only) mode
			SET @EXECstr = 'RESTORE DATABASE [' + @p_DestinationDbName + '] WITH STANDBY =''' + @p_TUFLocation + @p_DestinationDbName + '_undo.tuf''';
			PRINT @EXECstr
		
			IF @p_DryRun = 0
				EXEC(@EXECstr);
		END

		IF(@Failed = 1)
		BEGIN
			IF(@SuccessfullApply IS NULL)
				SET @EXECstr = 'No log file was applied due to missing file';
			ELSE
				SET @EXECstr = 'Restore operation failed which RESTORE LOG operation.  Last successful log file applied was ' + @SuccessfullApply;
			RAISERROR(@EXECstr, 11, 1)
		END
	END
	ELSE -- If no backup files to restore
	BEGIN
		PRINT	'No new Log files to apply.';
	END
END
GO
