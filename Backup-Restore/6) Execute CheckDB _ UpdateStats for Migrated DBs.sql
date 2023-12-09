/*	Created By:		AJAY DWIVEDI
	Created Date:	NOV 25, 2014
	Purpose:		Execute CheckDB & UpdateStats for migrated Databases
	Total Input:	1
*/
SET NOCOUNT ON;
DECLARE	@DB_Restore_Datetime DATETIME2;

--1) Set DateTime before migration here
SET	@DB_Restore_Datetime = CAST('2014-11-25 10:27:56.397' AS datetime2)-- SELECT GETDATE()

DECLARE @RestoredDBs TABLE 
(
	ID BIGINT IDENTITY(1,1),
	DBName VARCHAR(100),
	CreatedDate Date 
);
WITH LastRestores AS
(
	SELECT
		DatabaseName = [d].[name] ,
		[d].[create_date] ,
		[d].[compatibility_level] ,
		[d].[collation_name] ,
		r.*,
		RowNum = ROW_NUMBER() OVER (PARTITION BY d.Name ORDER BY r.[restore_date] DESC)
	FROM master.sys.databases d
	LEFT OUTER JOIN msdb.dbo.[restorehistory] r ON r.[destination_database_name] = d.Name
)
INSERT INTO @RestoredDBs
SELECT DatabaseName, COALESCE(restore_date,Create_date) as Last_Restore_Date
FROM [LastRestores]
WHERE [RowNum] = 1
AND	COALESCE(restore_date,Create_date) >= @DB_Restore_Datetime;

SELECT '
-- '+CAST(ID AS VARCHAR(2))+')
USE	 ['+DBName+']
GO
DBCC CHECKDB
GO
USE	 ['+DBName+']
GO
EXEC SP_UPDATESTATS;
GO'
FROM @RestoredDBs
GO