use StackOverflow
go

create or alter procedure dbo.usp_users_by_location @location varchar(100)
 with recompile
as
begin
	select *
	from dbo.Users u
	where u.Location like ('%'+@location+'%')
end
go

/*
select Location, count(*) as counts from dbo.Users group by Location order by counts desc
select top 1 location
from (values ('Laredo, TX'),('York, AL'),('Nigeria'),('UK'),('Sweden'),('India'),('United States')) UserLocations(location)
order by newid()
*/
