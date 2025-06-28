use DBA
go
-- https://www.youtube.com/watch?v=K6KyWzZS3Eg


/*
drop table dbo.lockme;
go

create table dbo.lockme
(id int not null, name varchar(100) not null, city varchar(125) null
,constraint pk_lockme primary key clustered (name)
);
go

insert dbo.lockme (id, name, city)
select 1, 'Ajay', 'Rewa'
union all
select 2, 'Anil', 'Hyderabad'
union all
select 3, 'Parshuram', 'Bangalore';
*/
go

-- Execute on Session 1
go
create or alter procedure dbo.usp_applock1
as
set xact_abort, nocount on
begin
	exec sys.sp_getapplock @Resource = 'lock0',
						@LockOwner = 'Session',
						@LockMode = 'Exclusive';

	update dbo.lockme set id = 2 where name = 'Anil';

	waitfor delay '00:00:10.000';

	exec sys.sp_releaseapplock @Resource = 'lock0',
						@LockOwner = 'Session';

end
go

-- Execute on Session 2
go
create or alter procedure dbo.usp_applock2
as
set xact_abort, nocount on
begin
	exec sys.sp_getapplock @Resource = 'lock0',
						@LockOwner = 'Session',
						@LockMode = 'Exclusive';

	update dbo.lockme set id = 2 where name = 'Ajay';

	waitfor delay '00:00:10.000';

	exec sys.sp_releaseapplock @Resource = 'lock0',
						@LockOwner = 'Session';

end
go