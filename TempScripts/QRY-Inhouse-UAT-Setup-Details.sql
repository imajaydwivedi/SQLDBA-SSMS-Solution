select distinct [ip], referenced_database_name from dbo.LinkedServersList ls where [ip] is not null
go
select distinct [ip] from dbo.LinkedServersList ls where [ip] is not null
go

select * from dbo.LinkedServersList l
where 1=1
go

select *
from LinkedServersList_Failed f
order by ip, referenced_database_name


alter table dbo.LinkedServersList
	add [status] varchar(20) null;

update dbo.LinkedServersList
	set [ip] = ltrim(rtrim(referenced_server_name))
where charindex('.',ltrim(rtrim(referenced_server_name))) > 0

select * from dbo.LinkedServersList
--update dbo.LinkedServersList set [ip] = '192.168.100.225'
where charindex('.',ltrim(rtrim(referenced_server_name))) = 0 and [ip] is null
and referenced_server_name = 'MARGINFIN'


