DECLARE @DbName nvarchar(50)
SET @DbName = N'Write a DB Name here'
 
DECLARE @EXECSQL varchar(max)
SET @EXECSQL = ''
 
SELECT @EXECSQL = @EXECSQL + 'Kill ' + Convert(varchar, SPId) + ';'
FROM MASTER..SysProcesses
WHERE DBId = DB_ID(@DbName) AND SPId  = @@SPId
 
EXEC(@EXECSQL)