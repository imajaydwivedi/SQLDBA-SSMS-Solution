use DBA
go

create table dbo.Test
( id int identity(1,1) not null,
	name varchar(50) not null,
	city varchar(50) null
)
go

insert dbo.Test
select 'Ajay', 'Rewa'
union all
select 'Gaurav', 'Rohtak'
union all
select 'Mani', 'Hyd'
go

/* Session 01 */
begin tran
	update dbo.Test
	set city = 'Hyd'
	where name = 'Ajay'

