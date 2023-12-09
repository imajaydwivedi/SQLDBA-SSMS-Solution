set nocount on;

if OBJECT_ID('tempdb..#TableSize') is not null
	drop table #TableSize;
create table #TableSize (
    [name] varchar(255),
    [rows] bigint,
    reserved varchar(255),
    [data] varchar(255),
    index_size varchar(255),
    unused varchar(255));

if OBJECT_ID('tempdb..#ConvertedSizes') is not null
	drop table #ConvertedSizes;
create table #ConvertedSizes (
    [table_name] varchar(255),
    [rows] bigint,
    reservedKb bigint,
    dataKb bigint,
    reservedIndexSize bigint,
    reservedUnused bigint,
	reservedMB as cast(reservedKb/1024.0 as numeric(20,2)),
	reservedGB as cast(reservedKb/1024.0/1024.0 as numeric(20,2)),
	dataMB as cast(dataKb/1024.0 as numeric(20,2)),
	)

EXEC sp_MSforeachtable @command1="insert into #TableSize
EXEC sp_spaceused '?'";
--exec sp_helptext 'sp_spaceused'

insert into #ConvertedSizes ([table_name], [rows], reservedKb, dataKb, reservedIndexSize, reservedUnused)
select [name], [rows], 
		SUBSTRING(reserved, 0, LEN(reserved)-2), 
		SUBSTRING(data, 0, LEN(data)-2), 
		SUBSTRING(index_size, 0, LEN(index_size)-2), 
		SUBSTRING(unused, 0, LEN(unused)-2)
from #TableSize

select [table_name], [rows], reservedMB, dataMB, 
		reserved = case when reservedMB/1024 > 0 then convert(varchar,reservedMB/1024)+' gb' else convert(varchar,reservedMB) +' mb' end, 
		data_size = case when dataMB/1024 > 0 then convert(varchar,dataMB/1024)+' gb' else convert(varchar,dataMB) +' mb' end, 
		reservedIndexSize, 
		reservedUnused
from #ConvertedSizes
where reservedMB > 5.0 
	--and ltrim(rtrim(table_name)) in ('user_stg','latest')
order by reservedKb desc;
