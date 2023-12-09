use StackOverflow
go

create or alter procedure dbo.Low_views_high_votes_yet_unanswered
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/951/low-views-high-votes-yet-unanswered
	-- Low views, high votes yet unanswered
	select top 500 Id as [Post Link], Score, ViewCount from Posts 
	where Score > 2 and ViewCount <> 0 and ParentId is null and AcceptedAnswerId is null
	order by ViewCount asc
end
go

--exec dbo.Low_views_high_votes_yet_unanswered
--go