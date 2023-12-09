$agNode = 'sqlag'

$tsql_CreateFunc = @"
IF OBJECT_ID('dbo.fn_GetHexaDecimal') IS NULL
	EXEC('CREATE FUNCTION dbo.fn_GetHexaDecimal () RETURNS int AS BEGIN RETURN (SELECT 1) END;');
"@;
$tsql_AlterFunc = @"
ALTER FUNCTION dbo.fn_GetHexaDecimal (@binvalue varbinary(256))
	RETURNS varchar (514)
AS
BEGIN
	DECLARE @hexvalue varchar (514)
	DECLARE @charvalue varchar (514)
	DECLARE @i int
	DECLARE @length int
	DECLARE @hexstring char(16)
	SELECT @charvalue = '0x'
	SELECT @i = 1
	SELECT @length = DATALENGTH (@binvalue)
	SELECT @hexstring = '0123456789ABCDEF'
	WHILE (@i <= @length)
	BEGIN
	  DECLARE @tempint int
	  DECLARE @firstint int
	  DECLARE @secondint int
	  SELECT @tempint = CONVERT(int, SUBSTRING(@binvalue,@i,1))
	  SELECT @firstint = FLOOR(@tempint/16)
	  SELECT @secondint = @tempint - (@firstint*16)
	  SELECT @charvalue = @charvalue +
		SUBSTRING(@hexstring, @firstint+1, 1) +
		SUBSTRING(@hexstring, @secondint+1, 1)
	  SELECT @i = @i + 1
	END

	SET @hexvalue = @charvalue;
	RETURN @hexvalue;
END
"@;

$tsql_GetLogins = @"
SELECT p.name, p.type, dbo.fn_GetHexaDecimal(p.sid) as sid
FROM master.sys.server_principals p 
WHERE p.type IN ( 'S', 'G', 'U' ) AND p.name <> 'sa';
"@;

Invoke-Sqlcmd -ServerInstance $agNode -Database tempdb -Query $tsql_CreateFunc | Out-Null;
Invoke-Sqlcmd -ServerInstance $agNode -Database tempdb -Query $tsql_AlterFunc | Out-Null;
$logins = Invoke-Sqlcmd -ServerInstance $agNode -Database tempdb -Query $tsql_GetLogins;
$logins | ogv