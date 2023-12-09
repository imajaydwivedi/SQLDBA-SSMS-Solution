use DBA
go

select top 10000 * 
into DBA.dbo.Users
from StackOverflow2010..Users

select top 10000 *
into DBA..Posts
from StackOverflow2010..Posts

alter table DBA.dbo.Users add constraint pk_users primary key (Id);
alter table DBA.dbo.Posts add constraint pk_Posts primary key (Id);

begin tran
	update DBA..Users
	set AboutMe = DisplayName
	where Id = 105
	
	select *
	from DBA..Users
	where Id = 15460;
