SET NOCOUNT ON;

declare @p_dbName varchar(100);
declare @_backupFile varchar(2000);
declare @_SourceServer varchar(255) = 'YourSourceServer';
declare @sqlRestoreText varchar(max);
declare @tsqlFetchLastBackup varchar(max);
declare @counter int = 1;
declare @total_counts int;
DECLARE @SourceBackups TABLE (DbName varchar(125), FullBackupFile varchar(2000));

IF OBJECT_ID('tempdb..#Dbs') IS NOT NULL
	DROP TABLE #Dbs;
SELECT ROW_NUMBER()OVER(ORDER BY dbName) as ID, dbName
INTO #Dbs
FROM (VALUES
			('Twitter'),('FaceBook')
	) Databases(dbName);
-- $SimpleDbs = @('Twitter', 'FaceBook')
select @total_counts = count(*) from #Dbs;

IF @_SourceServer IS NOT NULL
BEGIN
	SET @tsqlFetchLastBackup = '
	SELECT *
	FROM OPENROWSET(''SQLNCLI'', ''Server='+@_SourceServer+';Trusted_Connection=yes;'', ''select DbName, FullBackupFile from DBA..Vw_Latest_Backups'') AS v;
	';

	INSERT @SourceBackups
	EXEC (@tsqlFetchLastBackup);
END


while @counter <= @total_counts
BEGIN
	SELECT @_backupFile = NULL,@sqlRestoreText = '';
	SELECT @p_dbName = dbName FROM #Dbs d WHERE d.ID = @counter;

	IF @_SourceServer IS NOT NULL
	BEGIN
		SELECT @_backupFile = v.FullBackupFile
		FROM @SourceBackups AS v
		WHERE DbName = @p_dbName;

		SET @_backupFile = CASE WHEN CHARINDEX(':',@_backupFile) > 0 THEN '\\'+@_SourceServer+'\'+REPLACE(@_backupFile,':','$') ELSE @_backupFile END;
	END

	set @sqlRestoreText = '
	USE master;
	go
	EXEC master..sp_Kill @p_DbName = '''+@p_dbName+''' ,@p_Force = 1;
	go	
	RESTORE DATABASE '+QUOTENAME(@p_dbName)+' FROM  DISK = N'''+CASE WHEN @_backupFile IS NOT NULL THEN @_backupFile ELSE 'Your-Backup-File-Path-in-Here' END +'''
		WITH NORECOVERY
			 ,STATS = 3
			 ,REPLACE
	';

	select @sqlRestoreText += --name, physical_name,
	'		 ,MOVE N'''+name+''' TO N'''+physical_name+'''
	'
	from sys.master_files as mf 
	where mf.database_id = DB_ID(@p_dbName);

	SET @sqlRestoreText += '
	GO'

	PRINT @sqlRestoreText;

	SELECT @_backupFile = '',@sqlRestoreText = '', @p_dbName = '';
	SET @counter += 1;
END

/*
USE [DBA]
GO
ALTER VIEW [dbo].[Vw_Latest_Backups] AS
WITH T_Latest_Full AS
(
	SELECT	ROW_NUMBER()OVER(PARTITION BY bs.type ,bs.database_name ORDER BY bs.backup_finish_date DESC) as rownum,
			CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS SERVER
			,bs.database_name
			,bs.backup_start_date
			,bmf.physical_device_name
			,checkpoint_lsn
	FROM msdb.dbo.backupmediafamily AS bmf
	INNER JOIN msdb.dbo.backupset AS bs ON bmf.media_set_id = bs.media_set_id
	WHERE bs.type='D' 
	and bs.is_copy_only = 0
	--and bmf.physical_device_name like 'F:\dump\FullBackups2\%'
)
SELECT	f.SERVER as Server, f.database_name as DbName, f.physical_device_name as FullBackupFile,
		f.backup_start_date as FullBackupStartDate, f.checkpoint_lsn as Full_checkpoint_lsn
		,d.physical_device_name as DiffBackupFile ,d.backup_start_date as DiffBackupStartDate ,d.database_backup_lsn as Diff_database_backup_lsn
FROM T_Latest_Full as f
outer apply
(		SELECT TOP (1) bs.backup_start_date
				,bmf.physical_device_name
				,bs.database_backup_lsn
		FROM msdb..backupmediafamily AS bmf
		INNER JOIN msdb.dbo.backupset AS bs ON bmf.media_set_id = bs.media_set_id
		WHERE bs.type='I' and bs.database_name = f.database_name
			and f.checkpoint_lsn = bs.database_backup_lsn
			and bs.is_copy_only = 0
			and bmf.physical_device_name like 'F:\dump\DiffBackups\%'
		order by backup_start_date desc
) AS d
where F.rownum = 1;
GO
*/