/*	Created By:		AJAY DWIVEDI
	Created Date:	NOV 25, 2014
	Purpose:		Script out Take Backups
	Total Input:	3
*/

DECLARE @ID TINYINT --DB No
DECLARE @name VARCHAR(50) -- database name
DECLARE @Is_Copy_only TINYINT 
DECLARE @path VARCHAR(256) -- path for backup files  
DECLARE @fileName VARCHAR(256) -- filename for backup  
DECLARE @fileDate VARCHAR(20) -- used for file name
DECLARE @BackupString NVARCHAR(2000);
DECLARE @VerificationString NVARCHAR(2000);
 
--1) specify database backup directory
SET @path = 'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Backup'  
 
--2) Specify (True=1) or (False=0) for COPY_ONLY backup option
SET @Is_Copy_only = 1;

SELECT @fileDate = DATENAME(DAY,GETDATE())+CAST(DATENAME(MONTH,GETDATE()) AS VARCHAR(3))
		+DATENAME(YEAR,GETDATE())+'_'+REPLACE(REPLACE(RIGHT(CONVERT(VARCHAR, GETDATE(), 100),7),':',''), ' ','0')

--3) Specify your DB names for backup in case of data migration
DECLARE db_cursor CURSOR FOR  
	SELECT	ROW_NUMBER() OVER (ORDER BY name) as ID, name
	FROM master.dbo.sysdatabases 
	WHERE	DATABASEPROPERTYEX(NAME,'status') = 'ONLINE' 
	--AND		name IN ('Pubs')							-- Data Migration
	AND		name NOT IN ('master','model','msdb','tempdb')  -- Instance Migration
	ORDER BY name
 
OPEN db_cursor   
FETCH NEXT FROM db_cursor INTO @ID, @name;

 
WHILE @@FETCH_STATUS = 0   
BEGIN   
	
	SET	@BackupString = '
-- '+CAST(@ID AS VARCHAR(2))+') ['+@name+']
EXEC master.sys.xp_create_subdir '''+@path+'\'+@name+''';
GO
BACKUP DATABASE ['+@name+'] TO DISK = '''+@path+'\'+@name+'\'+ @name + '_' + @fileDate + '.BAK''
	 WITH '; 
	IF(@Is_Copy_only = 1)
		SET	@BackupString = @BackupString + 'COPY_ONLY, ';
	
	SET	@BackupString = @BackupString + 'STATS = 5 ,CHECKSUM, COMPRESSION;
GO';
	
	SET @VerificationString = '
declare @backupSetId as int
select @backupSetId = position from msdb..backupset where database_name=N'''+@name+''' and backup_set_id=(select max(backup_set_id) from msdb..backupset where database_name=N'''+@name+''' )
if @backupSetId is null begin raiserror(N''Verify failed. Backup information for database '''''+@name+''''' not found.'', 16, 1) end
RESTORE VERIFYONLY FROM  DISK = N'''+@path+'\'+@name+'\'+ @name + '_' + @fileDate + '.BAK'' WITH  FILE = @backupSetId,  NOUNLOAD,  NOREWIND
GO
';

	PRINT @BackupString;
	PRINT @VerificationString;
       FETCH NEXT FROM db_cursor INTO  @ID, @name;
END   

 
CLOSE db_cursor   
DEALLOCATE db_cursor