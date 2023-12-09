use Test
go

create table dbo.TestData
( id int identity(1,1), ColString01 char(4000) default replicate(char(65+(abs(checksum(NEWID()))%26)),4000), 
	ColString02 char(4000) default replicate(char(65+(abs(checksum(NEWID()))%26)),4000)
)

select * from Test.dbo.TestData

insert Test.dbo.TestData
values (default,default)
go

/* Single Record Read */
use Test;
select * from dbo.TestData where id = ABS(CHECKSUM(NEWID()));

/* Range Read */
use Test;
select * from dbo.TestData where id BETWEEN ABS(CHECKSUM(NEWID())) AND ABS(CHECKSUM(NEWID()));

/* Single Update */
update dbo.TestData
set ColString01 = replicate(char(65+(abs(checksum(NEWID()))%26)),4000)
where id = ABS(CHECKSUM(NEWID()))