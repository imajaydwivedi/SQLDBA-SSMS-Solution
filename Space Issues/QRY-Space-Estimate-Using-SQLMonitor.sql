use DBA
go

declare @host_name varchar(125);
declare @database_name varchar(125);
declare @object_name varchar(255);

select @host_name = host_name from dbo.instance_details;
set @object_name = (case when @@SERVICENAME = 'MSSQLSERVER' then 'SQLServer' else 'MSSQL$'+@@SERVICENAME end);
set @database_name = 'DBA'

;with t_size_start as (
	select top 1 'InitialSize' as QueryData, *
	from dbo.performance_counters pc
	where pc.host_name = @host_name
	and pc.object = (@object_name+':Databases') and pc.counter in ('Data File(s) Size (KB)')
		 and pc.instance = @database_name
	order by collection_time_utc asc
)
, t_size_latest as (
	select top 1 'CurrentSize' as QueryData, *
	from dbo.performance_counters pc
	where pc.host_name = @host_name
	and pc.object = (@object_name+':Databases') and pc.counter in ('Data File(s) Size (KB)')
		 and pc.instance = @database_name
	order by collection_time_utc desc
)
select 'Size-from-Start' as QueryData, i.collection_time_utc as start__collection_time_utc
		,i.value/1024/1024 as [start__size_gb] ,l.value/1024/1024 as [current__size_gb]
		,DATEDIFF(day,i.collection_time_utc, l.collection_time_utc) as [days-of-growth]
		,(l.value-i.value)/1024.0/1024.0 as [size_gb-of-growth]
		,(((l.value-i.value)/1024.0/1024.0)/(DATEDIFF(day,i.collection_time_utc, l.collection_time_utc)))*90 as [estimated-size_gb-for-90Days]
from t_size_latest l, t_size_start i;


