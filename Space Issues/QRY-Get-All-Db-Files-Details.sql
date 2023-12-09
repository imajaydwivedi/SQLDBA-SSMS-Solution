set nocount on;

set quoted_identifier off;
declare @dbname varchar(200);
declare @sql nvarchar(max);
if object_id('tempdb..#Dbs') is not null
	drop table #Dbs;
CREATE TABLE #Dbs
(
	[db_name] [nvarchar](128) NULL,
	[type_desc] [nvarchar](60) NULL,
	[file_group] [sysname] NULL,
	[name] [sysname] NULL,
	[physical_name] [nvarchar](500) NULL,
	[size_GB] [numeric](23, 11) NULL,
	[max_size] [int] NULL,
	[growth] [int] NULL,
	[SpaceUsed_gb] [numeric](38, 11) NULL,
	[FreeSpace_GB] [numeric](38, 11) NULL,
	[Used_Percentage] [decimal](20, 2) NULL,
	[log_reuse_wait_desc] [nvarchar](255) NULL
);

declare cur_db cursor forward_only for
	select name from sys.databases d 
	where database_id > 4
	--and name in ('uploader-db')
open cur_db
fetch next from cur_db into @dbname;

while @@FETCH_STATUS = 0
begin

	set @sql = "
use ["+@dbname+"];
select DB_NAME() AS [db_name], f.type_desc, fg.name as file_group, f.name, f.physical_name, (f.size*8.0)/1024/1024 as size_GB, f.max_size, f.growth, 
	CAST(FILEPROPERTY(f.name, 'SpaceUsed') as BIGINT)/128.0/1024 AS SpaceUsed_gb
		,(size/128.0 -CAST(FILEPROPERTY(f.name,'SpaceUsed') AS INT)/128.0)/1024 AS FreeSpace_GB
		,cast((FILEPROPERTY(f.name,'SpaceUsed')*100.0)/size as decimal(20,2)) as Used_Percentage
		,CASE WHEN f.type_desc = 'LOG' THEN (select d.log_reuse_wait_desc from sys.databases as d where d.name = DB_NAME()) ELSE NULL END as log_reuse_wait_desc
from sys.database_files f left join sys.filegroups fg on fg.data_space_id = f.data_space_id
order by FreeSpace_GB desc;
"
	insert #Dbs
	execute (@sql)

	fetch next from cur_db into @dbname;
end
close cur_db;
deallocate cur_db;

select * from #Dbs;

;with t_files_category as (
select f.db_name as [Database], [type_desc], [size_gb] = sum(size_GB)
from #Dbs f
--where f.db_name in ('Genodinlimit','StackOverflow','SB_comp','Upload')
group by f.db_name, [type_desc]
)
select [Database], convert(numeric(20,2),[ROWS]) as [MDF size(gb)], convert(numeric(20,2),[LOG]) as [LDF size(gb)]
from (
	select *
	from t_files_category fc
) p
pivot ( sum (size_gb) for type_desc in ([ROWS], [LOG]) ) as pvt;


