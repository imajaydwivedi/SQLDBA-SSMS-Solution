/*	Page Splits	*/
USE Ajay;

create table dbo.PageSplitDemo
(	ID INT NOT NULL,
	Data varchar(8000) null
)

create unique clustered index CI_UQ_PageSplitDemo
	on dbo.PageSplitDemo(ID);

;with tt as (select top 10000 ROW_NUMBER()over(order by a.number) as ID from master.dbo.spt_values as a cross apply master.dbo.spt_values as b)
insert dbo.PageSplitDemo (ID)
	select ID*2 from tt where ID <= 620;

select page_count, record_count, avg_page_space_used_in_percent
from sys.dm_db_index_physical_stats(db_id(),object_id(N'dbo.PageSplitDemo'),1,NULL,'DETAILED');
/*
page_count	record_count	avg_page_space_used_in_percent
1			620				99.5552260934025
*/
select * from dbo.PageSplitDemo;

insert into dbo.PageSplitDemo (ID, Data)
VALUES (101,REPLICATE('a',8000));

