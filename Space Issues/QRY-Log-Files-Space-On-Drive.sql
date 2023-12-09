CREATE TABLE #FreeSpace
(
	[DBName]		VARCHAR(50) NULL,
	[Type]			VARCHAR(50) NULL,
	[File_Name]		VARCHAR(100) NULL,
	[FileGroup_Name]	VARCHAR(100) NULL,
	[File_Location]		VARCHAR(250) NULL,
	FreeSpace_MB		DECIMAL(10,2) NULL
)
DECLARE @dBName	VARCHAR(50)
DECLARE @Query NVARCHAR(4000)
DECLARE curFreeSpace CURSOR FOR
SELECT name FROM sys.databases WHERE state_desc = 'ONLINE' --AND database_id > 4
OPEN curFreeSpace
FETCH NEXT FROM curFreeSpace INTO @dBName
WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @Query = 'USE [' + @dBName + ']
		INSERT INTO #FreeSpace
		SELECT ''' + @dbName + ''', [TYPE] = A.TYPE_DESC, [FILE_Name] = A.name, [FILEGROUP_NAME] = fg.name, [File_Location] = A.PHYSICAL_NAME
		--    ,[FILESIZE_MB] = CONVERT(DECIMAL(10,2),A.SIZE/128.0)
		--    ,[USEDSPACE_MB] = CONVERT(DECIMAL(10,2),A.SIZE/128.0 - ((SIZE/128.0) - CAST(FILEPROPERTY(A.NAME, ''SPACEUSED'') AS INT)/128.0))
			,[FREESPACE_MB] = CONVERT(DECIMAL(10,2),A.SIZE/128.0 - CAST(FILEPROPERTY(A.NAME, ''SPACEUSED'') AS INT)/128.0)
		FROM sys.database_files A LEFT JOIN sys.filegroups fg ON A.data_space_id = fg.data_space_id
		order by A.TYPE desc, A.NAME'
		exec (@Query)
		FETCH NEXT FROM curFreeSpace INTO @dbName
	END
CLOSE curFreeSpace
DEALLOCATE curFreeSpace
SELECT * FROM #FreeSpace
WHERE File_Location LIKE 'I%'
ORDER BY FreeSpace_MB DESC
DROP TABLE #FreeSpace
go

exec xp_fixeddrives