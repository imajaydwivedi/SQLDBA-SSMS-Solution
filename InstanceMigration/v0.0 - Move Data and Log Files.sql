--	=============================================================================================================
--	Created By:	Ajay Kumar Dwivedi
--	Usage:		Generate TSQL Script to move databases from Old path to New Path
--				https://dba.stackexchange.com/questions/52007/how-do-i-move-sql-server-database-files
--	Total INPUTS:	3
--	Version:	0.0
--	=============================================================================================================
SET NOCOUNT ON;

-- INPUT 01 -> Path for Data Files
DECLARE @p_Old_Data_Path varchar(255) = 'F:\'; -- Leave NULL if no change required
DECLARE @p_New_Data_Path varchar(255) = 'G:\'; -- Leave NULL if no change required

-- INPUT 02 -> Path for Log Files
DECLARE @p_Old_Log_Path varchar(255) = 'J:'; -- Leave NULL if no change required
DECLARE @p_New_Log_Path varchar(255) = 'y:'; -- Leave NULL if no change required

-- INPUT 03 -> Comma separated list of Databases
IF OBJECT_ID('tempdb..#Dbs2Consider') IS NOT NULL
	DROP TABLE #Dbs2Consider;
SELECT d.database_id, d.name, d.recovery_model_desc INTO #Dbs2Consider FROM sys.databases as d
	WHERE d.database_id > 4 
	AND d.name IN ('StackOverflow','AjayDatabase02')

--	Parameter Validations
DECLARE @NewLineChar AS CHAR(2) = CHAR(13) + CHAR(10)
DECLARE @_errorMSG VARCHAR(2000);
DECLARE @_IsValidParameter BIT = 1;
DECLARE @_Old_Data_Path varchar(255);
DECLARE @_New_Data_Path varchar(255);
DECLARE @_DataFileCounts int = 0;
DECLARE @_Old_Log_Path varchar(255);
DECLARE @_New_Log_Path varchar(255);
DECLARE @_LogFileCounts int = 0;
DECLARE @_robocopy_DataFiles VARCHAR(3000);
DECLARE @_robocopy_LogFiles VARCHAR(3000);

IF @p_Old_Data_Path IS NULL AND @p_New_Data_Path IS NULL AND @p_Old_Log_Path IS NULL AND @p_New_Log_Path IS NULL BEGIN SET @_IsValidParameter = 0 END
IF NOT((@p_Old_Data_Path IS NULL AND @p_New_Data_Path IS NULL) OR (@p_Old_Data_Path IS NOT NULL AND @p_New_Data_Path IS NOT NULL)) BEGIN SET @_IsValidParameter = 0 END
IF NOT((@p_Old_Log_Path IS NULL AND @p_New_Log_Path IS NULL) OR (@p_Old_Log_Path IS NOT NULL AND @p_New_Log_Path IS NOT NULL)) BEGIN SET @_IsValidParameter = 0 END

IF @_IsValidParameter = 0
BEGIN
	SET @_errorMSG = 'Kindly provide correct values for @p_Old_Data_Path/@p_New_Data_Path and @p_Old_Log_Path/@p_New_Log_Path.';
	IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
		EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
	ELSE
		EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
END

IF @_IsValidParameter = 1
BEGIN -- Begin block for @_IsValidParameter = 1
	SET @_Old_Data_Path = @p_Old_Data_Path;
	SET @_Old_Log_Path = @p_Old_Log_Path;
	
	;WITH T_File_Paths AS
	(
		SELECT	LEFT(mf.physical_name,LEN(mf.physical_name)-CHARINDEX('\',REVERSE(mf.physical_name))+1) as FilePath, COUNT(*) as FileCounts
		FROM	sys.master_files as mf
		WHERE	mf.database_id IN (SELECT d.database_id FROM #Dbs2Consider AS d)
			AND (mf.physical_name LIKE (@p_Old_Data_Path+'%') OR mf.physical_name LIKE (@p_Old_Log_Path+'%'))
		GROUP BY LEFT(mf.physical_name,LEN(mf.physical_name)-CHARINDEX('\',REVERSE(mf.physical_name))+1)
	)
	SELECT	@_Old_Data_Path = CASE WHEN LEN(@p_Old_Data_Path) <= 3	THEN CASE WHEN FilePath LIKE (@p_Old_Data_Path+'%') AND @_DataFileCounts < FileCounts THEN FilePath ELSE @_Old_Data_Path END ELSE @_Old_Data_Path END
			,@_Old_Log_Path = CASE WHEN LEN(@p_Old_Log_Path) <= 3	THEN CASE WHEN FilePath LIKE (@p_Old_Log_Path+'%') AND @_LogFileCounts < FileCounts THEN FilePath ELSE @_Old_Log_Path END ELSE @_Old_Log_Path END
			,@_New_Data_Path = CASE WHEN LEN(@p_New_Data_Path) <= 3	THEN CASE WHEN FilePath LIKE (@p_Old_Data_Path+'%') AND @_DataFileCounts < FileCounts THEN (LEFT(@p_New_Data_Path,1)+SUBSTRING(FilePath,2,LEN(FilePath))) ELSE @_New_Data_Path END ELSE @p_New_Data_Path END
			,@_New_Log_Path = CASE WHEN LEN(@p_New_Log_Path) <= 3	THEN CASE WHEN FilePath LIKE (@p_Old_Log_Path+'%') AND @_LogFileCounts < FileCounts THEN (LEFT(@p_New_Log_Path,1)+SUBSTRING(FilePath,2,LEN(FilePath))) ELSE @_New_Log_Path END ELSE @p_New_Log_Path END
			
			,@_DataFileCounts = CASE WHEN FilePath LIKE (@_Old_Data_Path+'%') AND @_DataFileCounts < FileCounts	THEN FileCounts ELSE @_DataFileCounts END
			--,@_LogFileCounts = CASE WHEN FilePath LIKE (@_Old_Log_Path+'%') AND @_LogFileCounts < FileCounts	THEN FileCounts ELSE @_LogFileCounts END
	FROM	T_File_Paths
	ORDER BY FileCounts desc;

	--SELECT	[@p_Old_Data_Path] = @p_Old_Data_Path, [@_Old_Data_Path] = @_Old_Data_Path, [@p_New_Data_Path] = @p_New_Data_Path, [@_New_Data_Path] = @_New_Data_Path
	--		,[@p_Old_Log_Path] = @p_Old_Log_Path, [@_Old_Log_Path] = @_Old_Log_Path, [@p_New_Log_Path] = @p_New_Log_Path, [@_New_Log_Path] = @_New_Log_Path

	PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------'
	SELECT	'ALTER DATABASE '+QUOTENAME(DB_NAME(mf.database_id))+
			' MODIFY FILE ( NAME = '''+mf.name+''', FILENAME = '''+ (CASE WHEN mf.type_desc = 'ROWS' THEN ISNULL(@_New_Data_Path,'@_New_Data_Path\') ELSE ISNULL(@_New_Log_Path,'@_New_Log_Path\') END) + (RIGHT(mf.physical_name,CHARINDEX('\',REVERSE(mf.physical_name))-1)) + ''');' + @NewLineChar + 'GO'
			AS [-- ************************* Modify MetaData to Move Data/Log Files *********************]
	FROM	sys.master_files as mf
	WHERE	mf.database_id IN (SELECT d.database_id FROM #Dbs2Consider AS d)
		AND (mf.physical_name LIKE (@p_Old_Data_Path+'%') OR mf.physical_name LIKE (@p_Old_Log_Path+'%'));

	SELECT 'ALTER DATABASE '+QUOTENAME(d.DbName)+' SET OFFLINE WITH ROLLBACK IMMEDIATE;' + @NewLineChar + 'GO'
	FROM (
		SELECT DISTINCT DB_NAME(mf.database_id) as DbName FROM sys.master_files as mf
		WHERE mf.database_id IN (SELECT d.database_id FROM #Dbs2Consider AS d) AND (mf.physical_name LIKE (@p_Old_Data_Path+'%') OR mf.physical_name LIKE (@p_Old_Log_Path+'%'))
	) AS d;

	--	Move Data Files
	IF @p_Old_Data_Path IS NOT NULL
	BEGIN
		SET @_robocopy_DataFiles = NULL
		PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------'
		SELECT	@_robocopy_DataFiles = COALESCE(@_robocopy_DataFiles+' '+'"'+f.FileBaseName+'"','"'+f.FileBaseName+'"')
		FROM  (
			SELECT (RIGHT(mf.physical_name,CHARINDEX('\',REVERSE(mf.physical_name))-1)) AS FileBaseName	FROM sys.master_files as mf	WHERE mf.database_id IN (SELECT d.database_id FROM #Dbs2Consider AS d) AND mf.physical_name LIKE (@p_Old_Data_Path+'%')
		) as f
		SET @_robocopy_DataFiles = 'robocopy "'+ @_Old_Data_Path +'" "'+ @_New_Data_Path + '" '+ @_robocopy_DataFiles + ' /it /MT';

		PRINT @_robocopy_DataFiles;
	END

	--	Move Log Files
	IF @p_Old_Log_Path IS NOT NULL
	BEGIN
		SET @_robocopy_LogFiles = NULL;
		SELECT	@_robocopy_LogFiles = COALESCE(@_robocopy_LogFiles+' '+'"'+f.FileBaseName+'"','"'+f.FileBaseName+'"')
		FROM  (
			SELECT (RIGHT(mf.physical_name,CHARINDEX('\',REVERSE(mf.physical_name))-1)) AS FileBaseName	FROM sys.master_files as mf	WHERE mf.database_id IN (SELECT d.database_id FROM #Dbs2Consider AS d) AND mf.physical_name LIKE (@p_Old_Log_Path+'%')
		) as f

		SET @_robocopy_LogFiles = 'robocopy "'+ @_Old_Log_Path +'" "'+ @_New_Log_Path + '" '+ @_robocopy_LogFiles + ' /it /MT';

		PRINT @_robocopy_LogFiles;
	END

	SELECT 'ALTER DATABASE '+QUOTENAME(d.DbName)+' SET ONLINE;' + @NewLineChar + 'GO'
	FROM (
		SELECT DISTINCT DB_NAME(mf.database_id) as DbName FROM sys.master_files as mf
		WHERE mf.database_id IN (SELECT d.database_id FROM #Dbs2Consider AS d) AND (mf.physical_name LIKE (@p_Old_Data_Path+'%') OR mf.physical_name LIKE (@p_Old_Log_Path+'%'))
	) AS d;

--SELECT db_name(database_id),* FROM sys.master_files mf where mf.database_id = db_id('StackOverflow')
END -- End block for @_IsValidParameter = 1
