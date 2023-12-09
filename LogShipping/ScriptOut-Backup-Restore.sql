DECLARE @fileName VARCHAR(256) -- filename for backup  
DECLARE @fileDate VARCHAR(20) -- used for file name
DECLARE @dbName VARCHAR(125) = 'Practice';
DECLARE @backupPath VARCHAR(125) = 'C:\MSSQL12.MSSQLSERVER\MSSQL\Backup\';
DECLARE @sqlString NVARCHAR(MAX);
DECLARE @backupType VARCHAR(20) = 'Full' /* Full, Log	*/
DECLARE @backupTypeContext VARCHAR(20);
DECLARE @backupExtension VARCHAR(20);

SELECT	@backupTypeContext = (CASE WHEN @backupType = 'Full' THEN 'DATABASE' ELSE 'LOG' END)
		,@backupExtension = CASE WHEN @backupType = 'Full' THEN '.bak' ELSE '.trn' END;

SELECT @fileDate = DATENAME(DAY,GETDATE())+CAST(DATENAME(MONTH,GETDATE()) AS VARCHAR(3))
		+DATENAME(YEAR,GETDATE())+'_'+REPLACE(REPLACE(RIGHT(CONVERT(VARCHAR, GETDATE(), 100),7),':',''), ' ','0');
SELECT @fileName = (SELECT @backupPath+@dbName+'_'+@backupTypeContext+'_'+ @fileDate + @backupExtension);

SET @sqlString = '
--	Execute on Primary Instance ''SQL-A''
BACKUP '+@backupTypeContext+' '+QUOTENAME(@dbName)+'
	TO DISK = '''+@fileName+''' WITH STATS = 3';

PRINT	@sqlString;
EXEC (@sqlString);

SET @sqlString = '
--	Execute on Secondary Instance ''SQL-B''
RESTORE '+@backupTypeContext+' '+QUOTENAME(@dbName)+'
	FROM DISK = '''+@fileName+''' WITH NORECOVERY, STATS = 3';

PRINT	@sqlString;