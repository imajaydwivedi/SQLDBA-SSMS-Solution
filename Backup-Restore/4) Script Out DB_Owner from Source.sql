/*	Created By:		AJAY DWIVEDI
	Created Date:	NOV 23, 2014
	Purpose:		Script out DB_OWNER
	Total Input:	1
*/

DECLARE @db_name NVARCHAR(100)
		,@DB_Owner NVARCHAR(150)
		,@SQLString NVARCHAR(max)
		,@ID TINYINT
		,@TotalCount TINYINT;

--1) Specify your DB names for backup in case of data migration
DECLARE database_cursor CURSOR FOR 
		SELECT	ROW_NUMBER()OVER(ORDER BY DB.name) AS ID, DB.name, SUSER_SNAME(DB.OWNER_SID) as DB_Owner
		FROM	master.sys.databases	AS DB
		--WHERE	DB.name IN ('SomeDatabaseName1', 'manish', 'AdventureWorks');	--DB Migration
		WHERE	DB.name NOT IN ('master','tempdb','model','msdb')				--Instance Migration
		
OPEN database_cursor
FETCH NEXT FROM database_cursor INTO @ID, @DB_Name, @DB_Owner;

WHILE @@FETCH_STATUS = 0 
BEGIN 
     SET @SQLString = '	
--'+CAST(@ID AS VARCHAR(2))+') 	
USE ['+@DB_Name+']
GO
IF (SELECT SUSER_SID('''+@DB_Owner+''') ) IS NOT NULL
	EXEC sp_changedbowner ['+@DB_Owner+']
ELSE
BEGIN
	PRINT ''DB_Owner ['+@DB_Owner+'] for ['+@DB_Name+'] database not found on Target Instance''
	EXEC sp_changedbowner [sa]
END
GO';

PRINT	@SQLString;

     FETCH NEXT FROM database_cursor INTO @ID, @DB_Name, @DB_Owner;
END 

CLOSE database_cursor 
DEALLOCATE database_cursor 