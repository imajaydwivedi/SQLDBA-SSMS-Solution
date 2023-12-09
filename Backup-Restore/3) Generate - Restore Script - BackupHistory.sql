SET NOCOUNT ON;
-- Input 01
DECLARE @p_Target_Data_Path varchar(255) = 'J:\MSSQL15.MSSQLSERVER\Data\';
-- Input 02
DECLARE @p_Target_Log_Path varchar(255) = 'J:\MSSQL15.MSSQLSERVER\Logs\'; 
-- Input 03
DECLARE @p_RestoreType varchar(20) = 'Log'; /* Full/Diff/Log */ 
-- Input 04
DECLARE @p_Leave_in_NORECOVERY_Mode bit = 1; /* Recover Database, means, Bring Online */ 
-- Input 05
DECLARE @p_ReplaceExistingDatabase bit = 0;
-- Input 06
DECLARE @Databases nvarchar(max) = 'Staging'; 
/*	-- https://ola.hallengren.com/sql-server-backup.html
	Select databases. The keywords SYSTEM_DATABASES, USER_DATABASES, ALL_DATABASES, and AVAILABILITY_GROUP_DATABASES are supported. The hyphen character (-) is used to exclude databases, and the percent character (%) is used for wildcard selection. All of these operations can be combined by using the comma (,).
*/

-- Input 07
DECLARE @p_Destination_ServerName VARCHAR(125) = 'YourDbServerName';
-- Input 08
DECLARE @p_Destination_BackupLocation VARCHAR(255) = 'F:\backups\';
-- Input 09
DECLARE @p_Generate_RoboCopy_4_Backups bit = 0;

DECLARE @SelectedDatabases TABLE (DatabaseName nvarchar(max),
                                    DatabaseType nvarchar(max),
                                    AvailabilityGroup nvarchar(max),
                                    Selected bit)
DECLARE @Version numeric(18,10)
DECLARE @p_Source_ServerName VARCHAR(125) = @@SERVERNAME;
DECLARE @p_Destination_BackupLocation_RoboCopy VARCHAR(255);
DECLARE @c_database_name VARCHAR(125);
DECLARE @c_physical_device_name VARCHAR(1000);
DECLARE @c_setNORECOVERY bit;
DECLARE @c_backup_type varchar(20);
DECLARE @c_FileName varchar(225);
declare @sqlRestoreText varchar(max);
DECLARE @ErrorMessage nvarchar(max);
DECLARE @Error int;
DECLARE @tmpDatabases TABLE (ID int IDENTITY,
                               DatabaseName nvarchar(max),
                               DatabaseNameFS nvarchar(max),
                               DatabaseType nvarchar(max),
                               AvailabilityGroup bit,
                               Selected bit,
                               Completed bit,
                               PRIMARY KEY(Selected, Completed, ID));
IF OBJECT_ID('tempdb..#RoboCopyTable') IS NOT NULL
	DROP TABLE #RoboCopyTable;
CREATE TABLE #RoboCopyTable (ID int IDENTITY, DirectoryName varchar(2000), FileName varchar(MAX));

SET @Version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10))

SET @p_Destination_BackupLocation = CASE WHEN RIGHT(LTRIM(RTRIM(@p_Destination_BackupLocation)),1) = '\' THEN LTRIM(RTRIM(@p_Destination_BackupLocation)) ELSE LTRIM(RTRIM(@p_Destination_BackupLocation))+'\' END;

SET @p_Destination_BackupLocation_RoboCopy = ( CASE WHEN charindex(':',@p_Destination_BackupLocation)<>0 THEN '\\'+@p_Destination_ServerName+'\'+REPLACE(@p_Destination_BackupLocation,':','$') ELSE @p_Destination_BackupLocation END )

--SELECT [@p_Destination_BackupLocation] = @p_Destination_BackupLocation, [@p_Destination_BackupLocation_RoboCopy] = @p_Destination_BackupLocation_RoboCopy;
  
  ----------------------------------------------------------------------------------------------------
  --// Select databases                                                                           //--
  ----------------------------------------------------------------------------------------------------
  SET @Databases = REPLACE(@Databases, CHAR(10), '')
  SET @Databases = REPLACE(@Databases, CHAR(13), '')

  WHILE CHARINDEX(', ',@Databases) > 0 SET @Databases = REPLACE(@Databases,', ',',')
  WHILE CHARINDEX(' ,',@Databases) > 0 SET @Databases = REPLACE(@Databases,' ,',',')

  SET @Databases = LTRIM(RTRIM(@Databases));

  WITH Databases1 (StartPosition, EndPosition, DatabaseItem) AS
  (
  SELECT 1 AS StartPosition,
         ISNULL(NULLIF(CHARINDEX(',', @Databases, 1), 0), LEN(@Databases) + 1) AS EndPosition,
         SUBSTRING(@Databases, 1, ISNULL(NULLIF(CHARINDEX(',', @Databases, 1), 0), LEN(@Databases) + 1) - 1) AS DatabaseItem
  WHERE @Databases IS NOT NULL
  UNION ALL
  SELECT CAST(EndPosition AS int) + 1 AS StartPosition,
         ISNULL(NULLIF(CHARINDEX(',', @Databases, EndPosition + 1), 0), LEN(@Databases) + 1) AS EndPosition,
         SUBSTRING(@Databases, EndPosition + 1, ISNULL(NULLIF(CHARINDEX(',', @Databases, EndPosition + 1), 0), LEN(@Databases) + 1) - EndPosition - 1) AS DatabaseItem
  FROM Databases1
  WHERE EndPosition < LEN(@Databases) + 1
  ),
  Databases2 (DatabaseItem, Selected) AS
  (
  SELECT CASE WHEN DatabaseItem LIKE '-%' THEN RIGHT(DatabaseItem,LEN(DatabaseItem) - 1) ELSE DatabaseItem END AS DatabaseItem,
         CASE WHEN DatabaseItem LIKE '-%' THEN 0 ELSE 1 END AS Selected
  FROM Databases1
  ),
  Databases3 (DatabaseItem, DatabaseType, AvailabilityGroup, Selected) AS
  (
  SELECT CASE WHEN DatabaseItem IN('ALL_DATABASES','SYSTEM_DATABASES','USER_DATABASES','AVAILABILITY_GROUP_DATABASES') THEN '%' ELSE DatabaseItem END AS DatabaseItem,
         CASE WHEN DatabaseItem = 'SYSTEM_DATABASES' THEN 'S' WHEN DatabaseItem = 'USER_DATABASES' THEN 'U' ELSE NULL END AS DatabaseType,
         CASE WHEN DatabaseItem = 'AVAILABILITY_GROUP_DATABASES' THEN 1 ELSE NULL END AvailabilityGroup,
         Selected
  FROM Databases2
  ),
  Databases4 (DatabaseName, DatabaseType, AvailabilityGroup, Selected) AS
  (
  SELECT CASE WHEN LEFT(DatabaseItem,1) = '[' AND RIGHT(DatabaseItem,1) = ']' THEN PARSENAME(DatabaseItem,1) ELSE DatabaseItem END AS DatabaseItem,
         DatabaseType,
         AvailabilityGroup,
         Selected
  FROM Databases3
  )
  INSERT INTO @SelectedDatabases (DatabaseName, DatabaseType, AvailabilityGroup, Selected)
  SELECT DatabaseName,
         DatabaseType,
         AvailabilityGroup,
         Selected
  FROM Databases4
  OPTION (MAXRECURSION 0)

  IF @Version >= 11 AND SERVERPROPERTY('EngineEdition') <> 5
  BEGIN
    INSERT INTO @tmpDatabases (DatabaseName, DatabaseNameFS, DatabaseType, AvailabilityGroup, Selected, Completed)
    SELECT [name] AS DatabaseName,
           LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([name],'\',''),'/',''),':',''),'*',''),'?',''),'"',''),'<',''),'>',''),'|',''))) AS DatabaseNameFS,
           CASE WHEN name IN('master','msdb','model') THEN 'S' ELSE 'U' END AS DatabaseType,
           CASE WHEN name IN (SELECT availability_databases_cluster.database_name FROM sys.availability_databases_cluster availability_databases_cluster) THEN 1 ELSE 0 END AS AvailabilityGroup,
           0 AS Selected,
           0 AS Completed
    FROM sys.databases
    WHERE [name] <> 'tempdb'
    AND source_database_id IS NULL
    ORDER BY [name] ASC
  END
  ELSE
  BEGIN
    INSERT INTO @tmpDatabases (DatabaseName, DatabaseNameFS, DatabaseType, AvailabilityGroup, Selected, Completed)
    SELECT [name] AS DatabaseName,
           LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([name],'\',''),'/',''),':',''),'*',''),'?',''),'"',''),'<',''),'>',''),'|',''))) AS DatabaseNameFS,
           CASE WHEN name IN('master','msdb','model') THEN 'S' ELSE 'U' END AS DatabaseType,
           NULL AS AvailabilityGroup,
           0 AS Selected,
           0 AS Completed
    FROM sys.databases
    WHERE [name] <> 'tempdb'
    AND source_database_id IS NULL
    ORDER BY [name] ASC
  END

  UPDATE tmpDatabases
  SET tmpDatabases.Selected = SelectedDatabases.Selected
  FROM @tmpDatabases tmpDatabases
  INNER JOIN @SelectedDatabases SelectedDatabases
  ON tmpDatabases.DatabaseName LIKE REPLACE(SelectedDatabases.DatabaseName,'_','[_]')
  AND (tmpDatabases.DatabaseType = SelectedDatabases.DatabaseType OR SelectedDatabases.DatabaseType IS NULL)
  AND (tmpDatabases.AvailabilityGroup = SelectedDatabases.AvailabilityGroup OR SelectedDatabases.AvailabilityGroup IS NULL)
  WHERE SelectedDatabases.Selected = 1

  UPDATE tmpDatabases
  SET tmpDatabases.Selected = SelectedDatabases.Selected
  FROM @tmpDatabases tmpDatabases
  INNER JOIN @SelectedDatabases SelectedDatabases
  ON tmpDatabases.DatabaseName LIKE REPLACE(SelectedDatabases.DatabaseName,'_','[_]')
  AND (tmpDatabases.DatabaseType = SelectedDatabases.DatabaseType OR SelectedDatabases.DatabaseType IS NULL)
  AND (tmpDatabases.AvailabilityGroup = SelectedDatabases.AvailabilityGroup OR SelectedDatabases.AvailabilityGroup IS NULL)
  WHERE SelectedDatabases.Selected = 0

  IF @Databases IS NOT NULL AND (NOT EXISTS(SELECT * FROM @SelectedDatabases) OR EXISTS(SELECT * FROM @SelectedDatabases WHERE DatabaseName IS NULL OR DatabaseName = ''))
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @Databases is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  ----------------------------------------------------------------------------------------------------
  --// Check database names                                                                       //--
  ----------------------------------------------------------------------------------------------------

  SET @ErrorMessage = ''
  SELECT @ErrorMessage = @ErrorMessage + QUOTENAME(DatabaseName) + ', '
  FROM @tmpDatabases
  WHERE Selected = 1
  AND DatabaseNameFS = ''
  ORDER BY DatabaseName ASC
  IF @@ROWCOUNT > 0
  BEGIN
    SET @ErrorMessage = 'The names of the following databases are not supported: ' + LEFT(@ErrorMessage,LEN(@ErrorMessage)-1) + '.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  
  SET @ErrorMessage = ''
  SELECT @ErrorMessage = @ErrorMessage + QUOTENAME(DatabaseName) + ', '
  FROM @tmpDatabases
  WHERE UPPER(DatabaseNameFS) IN(SELECT UPPER(DatabaseNameFS) FROM @tmpDatabases GROUP BY UPPER(DatabaseNameFS) HAVING COUNT(*) > 1)
  AND UPPER(DatabaseNameFS) IN(SELECT UPPER(DatabaseNameFS) FROM @tmpDatabases WHERE Selected = 1)
  AND DatabaseNameFS <> ''
  ORDER BY DatabaseName ASC
  OPTION (RECOMPILE)
  IF @@ROWCOUNT > 0
  BEGIN
    SET @ErrorMessage = 'The names of the following databases are not unique in the file system: ' + LEFT(@ErrorMessage,LEN(@ErrorMessage)-1) + '.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

--select @Databases;
--select * from @SelectedDatabases;
--select * from @tmpDatabases;

IF OBJECT_ID('tempdb..#T_bkpHistory') IS NOT NULL
	DROP TABLE #T_bkpHistory;
;WITH T_bkpHistory as
(
SELECT --ROW_NUMBER()over(partition by bs.database_name order by bs.backup_finish_date desc) as RowID,
		CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS SERVER
	,bs.database_name
	,bs.backup_start_date
	,bs.backup_finish_date
	,bs.expiration_date
	,CASE bs.type
		WHEN 'D'
			THEN 'Database'
		WHEN 'I'
			THEN 'Differential'
		WHEN 'L'
			THEN 'Log'
		END AS backup_type
	,convert(decimal(18,3),(bs.backup_size)/1024/1024) as backup_size_MB
	,convert(decimal(18,3),(bs.backup_size)/1024/1024/1024) as backup_size_GB
	,bmf.logical_device_name
	,bmf.physical_device_name
	,bs.NAME AS backupset_name
	,bs.description
	,first_lsn
	,last_lsn
	,checkpoint_lsn
	,database_backup_lsn
	,is_copy_only
	,ROW_NUMBER()OVER(PARTITION BY bs.database_name ORDER BY bs.backup_start_date) as BackupOrderID
	,DirectoryName = LEFT(physical_device_name, LEN(physical_device_name) - CHARINDEX('\',REVERSE(physical_device_name))+1)
	,FileName = RIGHT(physical_device_name,CHARINDEX('\',REVERSE(physical_device_name))-1)
	,CAST(NULL AS INT) AS [BackupOrderID_LatestDiff]
	,CAST(0 AS bit) AS [hasToBeScriptedOut]
	,CAST(1 AS bit) AS [setNORECOVERY]
FROM msdb.dbo.backupmediafamily AS bmf
INNER JOIN msdb.dbo.backupset AS bs ON bmf.media_set_id = bs.media_set_id
WHERE bs.is_snapshot = 0 AND bs.database_name IN (SELECT DatabaseName FROM @tmpDatabases d WHERE d.Selected = 1)
	-- Get all backups on/after Latest Full Backup
AND bs.backup_start_date >= (select max(bsi.backup_start_date) FROM msdb.dbo.backupmediafamily AS bmfi INNER JOIN msdb.dbo.backupset AS bsi ON bmfi.media_set_id = bsi.media_set_id where  bsi.is_snapshot = bs.is_snapshot AND bsi.database_name = bs.database_name and bsi.type = 'D' --and bmfi.physical_device_name not like '\\Sqlpdb01\%'
							  )
)
SELECT *
INTO #T_bkpHistory
FROM T_bkpHistory AS bh;

UPDATE #T_bkpHistory
SET [BackupOrderID_LatestDiff] = (SELECT MAX(bhi.BackupOrderID) FROM #T_bkpHistory AS bhi WHERE bhi.database_name = #T_bkpHistory.database_name AND bhi.backup_type = 'Differential');

UPDATE bh
SET [hasToBeScriptedOut] = 1
FROM #T_bkpHistory AS bh
WHERE CASE	WHEN	backup_type = 'Database'
			THEN	1
			WHEN	@p_RestoreType IN ('Diff','Log') AND backup_type = 'Differential' AND BackupOrderID = [BackupOrderID_LatestDiff]
			THEN	1
			WHEN	@p_RestoreType = 'Log' AND backup_type = 'Log'  AND BackupOrderID >= ISNULL([BackupOrderID_LatestDiff],0)
			THEN	1
			ELSE	0
			END = 1
--ORDER BY database_name, BackupOrderID;

IF @p_Leave_in_NORECOVERY_Mode = 0
BEGIN
	UPDATE bh 
	SET [setNORECOVERY] = CASE WHEN NOT EXISTS (SELECT * FROM #T_bkpHistory AS bhi WHERE bhi.database_name = bh.database_name AND bhi.[hasToBeScriptedOut] = 1 AND bhi.BackupOrderID > bh.BackupOrderID) THEN 0 ELSE 1 END
	FROM #T_bkpHistory AS bh
	WHERE [hasToBeScriptedOut] = 1;
END

--	SELECT * FROM #T_bkpHistory AS bh WHERE [hasToBeScriptedOut] = 1

-- If Full/Diff backups are to be copied on Destination before Restore, Generate RoboCopy statement
IF @p_Generate_RoboCopy_4_Backups = 1
BEGIN
	--https://stackoverflow.com/questions/31211506/how-stuff-and-for-xml-path-work-in-sql-server
	INSERT #RoboCopyTable
	SELECT DirectoryName
			,[Files] = (	SELECT '"' + bhi.FileName + '" '
							FROM #T_bkpHistory AS bhi
							WHERE bhi.[hasToBeScriptedOut] = 1 AND bhi.backup_type IN ('Database','Differential')
							AND bhi.DirectoryName = bh.DirectoryName
							FOR XML PATH ('')
						)
	FROM ( SELECT DISTINCT DirectoryName FROM #T_bkpHistory WHERE [hasToBeScriptedOut] = 1 AND backup_type IN ('Database','Differential')) AS bh;

	DECLARE @_counter smallint = 1;
	DECLARE @_roboCopyText VARCHAR(MAX);
	WHILE(@_counter <= (SELECT MAX(ID) FROM #RoboCopyTable))
	BEGIN
		SET @_roboCopyText = NULL;
		SELECT @_roboCopyText = 'robocopy '+DirectoryName+' '+@p_Destination_BackupLocation_RoboCopy+' '+FileName+' /it' FROM #RoboCopyTable WHERE ID = @_counter;
		SELECT 'robocopy '+DirectoryName+' '+@p_Destination_BackupLocation_RoboCopy+' '+FileName FROM #RoboCopyTable WHERE ID = @_counter;
		PRINT CHAR(10)+@_roboCopyText;
		SET @_counter += 1;
	END
	
END

DECLARE cur_Backups CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
						SELECT database_name, physical_device_name, [setNORECOVERY], backup_type, FileName
						FROM #T_bkpHistory AS bh
						WHERE [hasToBeScriptedOut] = 1
						ORDER BY database_name, BackupOrderID;

OPEN cur_Backups;

FETCH NEXT FROM cur_Backups INTO @c_database_name, @c_physical_device_name, @c_setNORECOVERY, @c_backup_type, @c_FileName;

WHILE @@FETCH_STATUS = 0
BEGIN
	--PRINT '@c_database_name = '+@c_database_name+CHAR(13)+CHAR(10)+'@c_physical_device_name = '+@c_physical_device_name;
	set @sqlRestoreText = '
	RESTORE DATABASE '+QUOTENAME(@c_database_name)+' FROM  DISK = N'''+(CASE WHEN @p_Generate_RoboCopy_4_Backups = 1 AND @c_backup_type IN ('Database','Differential') THEN @p_Destination_BackupLocation+@c_FileName ELSE ( case when charindex(':',@c_physical_device_name)<>0 then '\\'+@@SERVERNAME+'\'+REPLACE(@c_physical_device_name,':','$') else @c_physical_device_name end ) END)+'''
		WITH '+(CASE WHEN @c_setNORECOVERY = 1 THEN 'NORECOVERY' ELSE 'RECOVERY' END)+'
			 ,STATS = 3'+(CASE WHEN @p_ReplaceExistingDatabase = 1 AND @c_backup_type = 'Database' THEN '
			 ,REPLACE' ELSE '' END)+'			 
	';

	IF @c_backup_type = 'Database'
	BEGIN
		select @sqlRestoreText += --name, physical_name,
		'		 ,MOVE N'''+name+''' TO N'''+(case when mf.type_desc = 'ROWS' then @p_Target_Data_Path ELSE @p_Target_Log_Path END )+ RIGHT(mf.physical_name,CHARINDEX('\',REVERSE(mf.physical_name))-1) +'''
		'
		from sys.master_files as mf 
		where mf.database_id = DB_ID(@c_database_name);
	END

	SET @sqlRestoreText += '
	GO'

	PRINT @sqlRestoreText;

	FETCH NEXT FROM cur_Backups INTO @c_database_name, @c_physical_device_name, @c_setNORECOVERY, @c_backup_type, @c_FileName;
END
