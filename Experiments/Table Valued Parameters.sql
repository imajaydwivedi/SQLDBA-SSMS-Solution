use StackOverflow
go
/*	https://learn.microsoft.com/en-us/sql/relational-databases/tables/use-table-valued-parameters-database-engine?view=sql-server-ver16

	ISSUE -> SQL Server does not maintain statistics on columns of table-valued parameters. So there is high chance of Cardinality Estimation issues.
	ISSUE -> Queries using table valued parameters don't get Parallel plans

https://learn.microsoft.com/en-us/sql/relational-databases/tables/use-table-valued-parameters-database-engine?view=sql-server-ver16#:~:text=SQL%20Server%20does%20not%20maintain%20statistics%20on%20columns%20of%20table%2Dvalued%20parameters.
*/

create type StackUser as table (UserId int not null);
go

create or alter procedure dbo.usp_GetUsersPosts_TVP
	@StackUserType StackUser READONLY
as
begin
	select u.Id, u.DisplayName, u.Location, p.PostTypeId, p.Title
	from dbo.Posts p
	join @StackUserType ut
		on p.OwnerUserId = ut.UserId
	join dbo.Users u
		on u.Id = ut.UserId;

end
go

create or alter procedure dbo.usp_GetUsersPosts_TVP_TempTable
	@StackUserType StackUser READONLY
as
begin
	if object_id('tempdb..#StackUserType') is not null
		drop table #StackUserType;

	select * into #StackUserType from @StackUserType;
	
	select ut.UserId, u.DisplayName, u.Location,  p.Id as PostId
	into #relevantUserPosts
	from #StackUserType ut		
	join dbo.Users u
		on u.Id = ut.UserId
	join dbo.Posts p
		on p.OwnerUserId = ut.UserId
	--option (recompile);
	
	select Id = rp.UserId, rp.DisplayName, rp.Location, p.PostTypeId, p.Title
	from #relevantUserPosts rp
	join dbo.Posts p
		on p.Id = rp.PostId;

end
go

set statistics time, io on;
go


declare @UserTable as StackUser;

insert @UserTable 
--values (1)
--,(4449743),(26837),(545629),(61305),(440595),(4197),(17174);
select top 100000 Id from dbo.Users

exec dbo.usp_GetUsersPosts_TVP @UserTable with recompile
go

print '*************************************************************************'
go

declare @UserTable as StackUser;

insert @UserTable 
--values (1)
--,(4449743),(26837),(545629),(61305),(440595),(4197),(17174);
select top 100000 Id from dbo.Users

exec dbo.usp_GetUsersPosts_TVP_TempTable @UserTable;
go



