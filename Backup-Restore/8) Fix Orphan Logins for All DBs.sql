DECLARE	@ID INT
		,@RecordsInserted INT
		,@DBName VARCHAR(200)
		,@String NVARCHAR(4000)
		
DECLARE	@OrphanLoginsTable TABLE
(
	ID INT IDENTITY(1,1)
	,DBName VARCHAR(200)
	,UserName VARCHAR(200)
	,UserSID VARCHAR(2000)
)		

DECLARE myCursor CURSOR FOR
	SELECT	name
	FROM	sys.databases
	WHERE	name not in ('master','model','msdb','tempdb')

OPEN myCursor
FETCH NEXT FROM myCursor INTO @DBName;

WHILE @@FETCH_STATUS = 0 
BEGIN 
	
	SET	@String = '
USE ['+@DBName+']
EXEC sp_change_users_login ''Report'';
';
	SET NOCOUNT ON;
	INSERT INTO @OrphanLoginsTable
	(UserName, UserSID)
	EXEC sp_executesql @String;
	
	SET @RecordsInserted = @@ROWCOUNT;
	SET @ID = @@IDENTITY;
	
	IF	@RecordsInserted <> 0
	BEGIN
		SELECT	'USE ['+@DBName+'];
Exec sp_change_users_login ''auto_fix'','''+UserName+'''  		
'		 
		FROM	@OrphanLoginsTable;
	END
	
	DELETE FROM @OrphanLoginsTable;
FETCH NEXT FROM myCursor INTO @DBName;
END

CLOSE myCursor 
DEALLOCATE myCursor 
