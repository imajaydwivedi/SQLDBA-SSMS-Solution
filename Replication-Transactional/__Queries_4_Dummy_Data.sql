USE [DbaReplication]
GO

CREATE TABLE [dbo].[ReplTable03]
(
	[ID] BIGINT IDENTITY(1,1) PRIMARY KEY,
	[ColStr01] [char](4000) NULL default REPLICATE(CHAR(ABS(CHECKSUM(NEWID()))%26+65),4000),
	[ColStr02] [varchar](3000) NULL default REPLICATE(CHAR(ABS(CHECKSUM(NEWID()))%26+65),3000),
	created_date datetime default getdate()
)
GO

$dbServer = 'YourDbServerName';
$dbName = 'DbaReplication';
$query = @"
insert dbo.ReplTable03
values (default,default,default)
"@

while($true) {
    Invoke-DbaQuery -SqlInstance $dbServer -Database $dbName -Query $query;
    Start-Sleep -Seconds 10;
}



use DBA
go
--drop table dbo.ReplTest01
create table dbo.ReplTest01
(id bigint identity(1,1) not null primary key,
 colstring01 char(20) not null,
 colstring02 varchar(500) not null,
 colstring03 varchar(500) not null
)
GO

INSERT dbo.ReplTest01
select top 10000 REPLICATE(CHAR((ABS(CHECKSUM(NEWID()))%25)+65),20), isnull(v1.name,' ') +' '+ isnull(v2.name,' '), isnull(v2.name,' ') +' '+ isnull(v1.name,' ')
from master..spt_values v1 cross join master..spt_values v2
order by NEWID()
GO 100

select COUNT(*) from DBA.dbo.ReplTest01
select COUNT(*) from DBARepl.dbo.ReplTest01