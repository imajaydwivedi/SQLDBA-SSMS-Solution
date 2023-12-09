/*	Created By:		AJAY DWIVEDI
	Created Date:	Apr 29, 2021
	Purpose:		Set DB Compatibility as per model database
*/
SET NOCOUNT ON;

/* Parameter */
DECLARE @p_executeDynamicQuery bit = 1;
DECLARE @p_compatibility tinyint;
--SET @p_compatibility = 110; /* Comment this line if Latest Compatability is required */

/* Local Variables */
DECLARE @db_name NVARCHAR(100)
		,@log_file NVARCHAR(150)
		,@SQLString NVARCHAR(max);

IF @p_compatibility is null
	SET @p_compatibility = (SELECT compatibility_level FROM sys.databases WHERE name = 'model');

DECLARE database_cursor CURSOR FOR
		SELECT	db.name
		FROM	sys.databases	AS db
		WHERE	db.name NOT IN ('master','tempdb','model','msdb')
		AND		db.state_desc = 'ONLINE' AND DATABASEPROPERTYEX (db.name, 'Updateability') = 'READ_WRITE'
		AND		db.compatibility_level <> @p_compatibility;
		--sys.dm_hadr_database_replica_states

OPEN database_cursor
FETCH NEXT FROM database_cursor INTO @db_name;

WHILE @@FETCH_STATUS = 0
BEGIN
     SET @SQLString =
'ALTER DATABASE [' + @db_name + '] SET COMPATIBILITY_LEVEL = ' + CAST(@p_compatibility AS VARCHAR(3)) + ';';

	IF @p_executeDynamicQuery = 1
	BEGIN
		PRINT 'Executing "'+@SQLString+'"';
		BEGIN TRY
			EXEC (@SQLString)
		END TRY
		BEGIN CATCH
			SELECT @SQLString AS [TSQL-Statement]
				,ERROR_NUMBER() AS ErrorNumber
				,ERROR_STATE() AS ErrorState
				,ERROR_SEVERITY() AS ErrorSeverity
				,ERROR_PROCEDURE() AS ErrorProcedure
				,ERROR_LINE() AS ErrorLine
				,ERROR_MESSAGE() AS ErrorMessage;
	END CATCH
	END
	ELSE
	BEGIN
		PRINT	@SQLString+'
GO';
	END

     FETCH NEXT FROM database_cursor INTO @db_name;
END

CLOSE database_cursor
DEALLOCATE database_cursor
GO