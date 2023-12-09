use DBA
go

--drop table dbo.my_heap_table 
if OBJECT_ID('dbo.my_heap_table') is null
	create table dbo.my_heap_table 
	(	id bigint identity(1,1) not null, 
		col1 varchar(500) null default 'a', 
		col2 nvarchar(2000) null default 'b'

		,index uq_id unique (id)
	);
go

select count(*) from dbo.my_heap_table
go

/* Let populate 1 million rows. Approx time 00:03:30 */
set nocount on;
go

begin tran
GO
insert dbo.my_heap_table values (default, default);
GO 1000000
GO
commit tran
go

checkpoint
go

/* Let's update 5% rows of table. Expected time 20 seconds */
begin tran
go
update dbo.my_heap_table 
set col1 = replicate(nchar(65+floor(RAND()*26)),floor(RAND()*49)),
	col2 = replicate(nchar(65+floor(RAND()*26)),floor(RAND()*200))
where id = FLOOR(RAND()*1000000)
go 50000
go
commit tran
go

checkpoint
go

exec sp_BlitzIndex @DatabaseName = 'DBA', @TableName = 'my_heap_table'
-- 1,000,000 rows; 36.9MB
-- Check [Usage Stats], [Op Stats], [Size], 
go

set statistics time, io on;
go
/* Observation 01 -> Let's scan entire data */
select * from sys.dm_db_index_physical_stats(db_id(),object_id('dbo.my_heap_table'),null,null,null) ips
-- avg_fragmentation_in_percent = 63.38, page_count = 4716 (Heap) + 2718 (NCI)

select * from dbo.my_heap_table;
-- logical reads 40530, CPU time = 188 ms,  elapsed time = 2908 ms
go


declare @start_id bigint = FLOOR(RAND()*1000000);
declare @end_id bigint = @start_id+(2000-1);
exec sp_executesql N'select * from dbo.my_heap_table where id between @start_id and @end_id;',
				N'@start_id bigint, @end_id bigint', @start_id, @end_id;
-- logical reads 2089, CPU time = 0 ms,  elapsed time = 6 ms.
go

dbcc freeproccache
go

