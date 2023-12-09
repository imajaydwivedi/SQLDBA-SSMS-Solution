use StackOverflow
go

create or alter procedure dbo.usp_Most_controversial_posts
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/466/most-controversial-posts-on-the-site
	set nocount on 

	declare @VoteStats table (PostId int, up int, down int) 

	insert @VoteStats
	select
		PostId, 
		up = sum(case when VoteTypeId = 2 then 1 else 0 end), 
		down = sum(case when VoteTypeId = 3 then 1 else 0 end)
	from Votes
	where VoteTypeId in (2,3)
	group by PostId

	set nocount off


	select top 100 p.id as [Post Link] , up, down from @VoteStats 
	join Posts p on PostId = p.Id
	where down > (up * 0.5) and p.CommunityOwnedDate is null and p.ClosedDate is null
	order by up desc
end
go

exec dbo.usp_Most_controversial_posts
go