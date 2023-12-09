use tempdb
go
set nocount on;
go

truncate table dbo.time_dimension;

declare @start_time datetime = '2020-01-01 00:00:00';
declare @end_time datetime = '2022-01-01 00:00:00';

select [@start_time] = @start_time, [@end_time] = @end_time, DATEADD(second,10,@start_time);

declare @counter_time datetime = @start_time
while(@counter_time < @end_time)
begin
	begin try
		insert dbo.time_dimension
		values (@counter_time)
	end try
	begin catch
		print 'Error while trying to insert - '+ convert(nvarchar,@counter_time,120);
	end catch

	set @counter_time = DATEADD(second,10,@counter_time);
end
go

select *
from dbo.time_dimension
go
/*
--drop table dbo.time_dimension
create table dbo.time_dimension
(date_time datetime not null primary key clustered);
go
*/