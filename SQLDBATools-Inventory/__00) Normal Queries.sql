USE SQLDBATOOLS
GO

/*
$Columns = Invoke-DbaQuery -SqlInstance 'DbaTestServer\sql2016' -Database 'SQLDBATools' -Query "SELECT * FROM Information_schema.columns c where c.table_name = 'ServerInfo'"
($Columns | Select-Object -ExpandProperty COLUMN_NAME) -join ', ' | ogv;
*/

SELECT * FROM dbo.Server with(nolock);
select * from Staging.ServerInfo with(nolock)
select * from [Staging].[CollectionErrors] with(nolock)
--select 'Login Failed' as Category, * from [Staging].[CollectionErrors] as e with(nolock) where e.Error like '%Login failed for user%'
--select * from Staging.ServerInfo with(nolock) where LEFT([FQDN],CHARINDEX('.',[FQDN])-1) <> ServerName
/*
update Staging.ServerInfo
set ServerName = LEFT([FQDN],CHARINDEX('.',[FQDN])-1)
where ServerName <> LEFT([FQDN],CHARINDEX('.',[FQDN])-1)
*/
/*
truncate table [Staging].[ServerInfo]
truncate table dbo.Server
truncate table [Staging].[CollectionErrors]
*/
--select 1 as IsPresent from [SQLDBATools].[dbo].[Server] where FQDN = 'DbaTestServer.contso.com'

/*
	EXEC [Staging].[usp_ETL_ServerInfo];
*/

select * from dbo.Server s where s.IsStandaloneServer = 1 or s.IsSqlCluster = 1 or s.IsAG = 1 or s.IsAgNode = 1


use SQLDBATools
--select * from Staging.CollectionErrors with (nolock) where CollectionTime > DATEADD(hh,-5,getdate())
--delete from Staging.CollectionErrors where CollectionTime > DATEADD(hh,-5,getdate())
select * from dbo.Server s
select * from dbo.Instance
select * from dbo.Application
--select * from Staging.InstanceInfo with (nolock)
--select * from Staging.InstanceInfo as i with (nolock) where i.ServerName = 'DbServerName'
--select * from Staging.ServerInfo
--select * from  INFORMATION_SCHEMA.COLUMNS C WHERE C.TABLE_NAME = 'InstanceInfo'
--select * from sys.all_columns c where c.object_id = OBJECT_ID('Staging.InstanceInfo')
/*
drop table dbo.Server
drop table dbo.Instance
truncate table Staging.InstanceInfo
*/

use SQLDBATools
declare @objectName varchar(50) = 'application'
select	[list_tableHeaders] = '<th scope="col">'+c.name+'</th>',
		[list_tableData] = '<td>{{'+@objectName+'.'+LOWER(REPLACE(c.name,'_',''))+'}}</td>',
		[detail_tableData] = case	when c.column_id%2=1 then '<tr class="bg-transpart"><td>'+c.name+'</td><td>{{'+@objectName+'_detail.'+LOWER(REPLACE(c.name,'_',''))+'}}</td></tr>'
									else '<tr class="bg-light"><td>'+c.name+'</td><td>{{'+@objectName+'_detail.'+LOWER(REPLACE(c.name,'_',''))+'}}</td></tr>'
									end
from  sys.columns c WHERE OBJECT_NAME(c.object_id) = @objectName
order by c.column_id asc

--select * from sys.columns c WHERE OBJECT_NAME(c.object_id) = @objectName

select	Category, BusinessUnit, BusinessOwner, TechnicalOwner, SecondaryTechnicalOwner
from	SQLDBATools..Application as a;

--	Single record Applications
;WITH T_Apps AS (
select [Category], [BusinessUnit], [Businessowner], [TechnicalOwner], [SecondaryTechnicalOwner]
		,ROW_NUMBER()over(ORDER by [Category], [BusinessUnit], [Businessowner], [TechnicalOwner], [SecondaryTechnicalOwner]) as RecordID
from [DbaTestServer\SQL2016].[contsoSQLInventory].dbo.Server s
where (s.Businessowner is not null or s.[TechnicalOwner] is not null or s.[SecondaryTechnicalOwner] is not null)
group by [Category], [BusinessUnit], [Businessowner], [TechnicalOwner], [SecondaryTechnicalOwner]
--order by [Category], [BusinessUnit], [Businessowner], [TechnicalOwner], [SecondaryTechnicalOwner]
)
SELECT	Category, BusinessUnit, BusinessOwner, TechnicalOwner, SecondaryTechnicalOwner
INTO #Application
FROM	T_Apps as a
where	a.RecordID not in (1,3,4,7,27,29,32,36)
ORDER BY a.RecordID ASC;

select * 
into #contsoSQLInventory_Server
from [DbaTestServer\SQL2016].[contsoSQLInventory].dbo.Server


update s
set s.ApplicationID = a.ApplicationID
--select	b.ServerID, b.Server, b.ShortDescription, b.AdditionalNotes, s.FQDN, a.ApplicationID
from #contsoSQLInventory_Server as b
inner join dbo.Application as a
	on a.BusinessUnit = ltrim(rtrim(b.BusinessUnit))
	and a.Category = ltrim(rtrim(b.Category))
	and a.BusinessOwner = ltrim(rtrim(b.BusinessOwner))
	and a.TechnicalOwner = ltrim(rtrim(b.TechnicalOwner))
	and a.SecondaryTechnicalOwner = ltrim(rtrim(b.SecondaryTechnicalOwner))
inner join dbo.Server as s 
	on s.ServerName = b.server




INSERT dbo.Application
(Category, BusinessUnit, BusinessOwner, TechnicalOwner, SecondaryTechnicalOwner)
SELECT ltrim(rtrim(Category)), ltrim(rtrim(BusinessUnit)), ltrim(rtrim(BusinessOwner)), ltrim(rtrim(TechnicalOwner)), ltrim(rtrim(SecondaryTechnicalOwner))
FROM #Application



--	BEGIN: Query to Get Update Column =============================================================================
declare @compQuery varchar(4000);
declare @columnName varchar(125);
declare @tableName varchar(225);

set @tableName = 'dbo.Server'

DECLARE col_cursor CURSOR LOCAL FAST_FORWARD FOR   
	SELECT Column_Name
	FROM INFORMATION_SCHEMA.COLUMNS c
	where c.TABLE_SCHEMA+'.'+c.TABLE_NAME = @tableName
	order by c.ORDINAL_POSITION;

OPEN col_cursor; 
FETCH NEXT FROM col_cursor INTO @columnName;

WHILE @@FETCH_STATUS = 0  
BEGIN 
	SET @compQuery = '
	UPDATE I SET '+QUOTENAME(@columnName)+' = N.'+QUOTENAME(@columnName)+'
	FROM #StagingServerInfo as N INNER JOIN	[dbo].[Server] as I ON	I.FQDN = N.FQDN	WHERE N.RowID = 1 AND N.[NeedUpdate] = 1
		AND N.'+QUOTENAME(@columnName)+' IS NOT NULL AND ISNULL(I.'+QUOTENAME(@columnName)+','''') <> N.'+QUOTENAME(@columnName)+';'

	PRINT @compQuery;
	FETCH NEXT FROM col_cursor INTO @columnName;
END

CLOSE vendor_cursor;  
DEALLOCATE vendor_cursor;  
--	END: Query to Get Update Column =============================================================================
