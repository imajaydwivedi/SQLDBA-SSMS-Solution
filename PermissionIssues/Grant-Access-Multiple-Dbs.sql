SET NOCOUNT ON;

if OBJECT_ID('tempdb..#dbs') is not null
	drop table #dbs;
select IDENTITY(INT,1,1) AS id, dbName
into #dbs
from (values --('Youtube_20130710_AudioMusic'),
			 --('StackOverflow'),('Facebook'),('Vision'),('Staging')
			 ('DBAVideo_Filter_Perf'),('Galaxys'),('DBAVideo1_1_Filter_Perf1')
	 ) as Dbs (dbName)

declare @dbCounter int;
declare @tsql varchar(4000);
declare @dbName varchar(200);

set @dbCounter= (select COUNT(*) from #dbs);

set @tsql = '
USE [master]
GO
CREATE LOGIN [Domain\UserName] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
GO
'

while(@dbCounter > 0)
begin
	
	select @dbName = dbName from #dbs where ID = @dbCounter;

	set @tsql += '

USE ['+@dbName+']
GO
CREATE USER [Domain\UserName] FOR LOGIN [Domain\UserName]
GO
EXEC sp_addrolemember N''db_datareader'', N''contso\yc''
GO
EXEC sp_addrolemember N''db_datawriter'', N''contso\yc''
GO
EXEC sp_addrolemember N''db_viewdefs'', N''contso\yc''
GO
GRANT EXECUTE TO [Domain\UserName]
GO
GRANT VIEW DEFINITION TO [Domain\UserName]
GO
'
	print @tsql;
	set @tsql = '';
	set @dbCounter = @dbCounter - 1;
end