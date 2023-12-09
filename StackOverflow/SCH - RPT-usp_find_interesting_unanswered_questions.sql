use StackOverflow
go

create or alter procedure dbo.usp_find_interesting_unanswered_questions @UserId int
as
begin
	-- Find interesting unanswered questions
	-- Looks at unanswered questions in your top 20 tags and sorts them by
	-- a combined weight which takes into account: score, askers reputation and how
	-- well you do on that particular tag

	create table #tags (TagId int, [Count] int)

	insert #tags 
	SELECT TOP 20 
		TagId,
		COUNT(*) AS UpVotes 
	FROM Tags
		INNER JOIN PostTags ON PostTags.TagId = Tags.id
		INNER JOIN Posts ON Posts.ParentId = PostTags.PostId
		INNER JOIN Votes ON Votes.PostId = Posts.Id and VoteTypeId = 2
	WHERE 
		Posts.OwnerUserId = @UserId
	GROUP BY TagId
	ORDER BY UpVotes DESC


	create table #unanswered (Id int primary key)

	insert #unanswered 
	select q.Id  from Posts q
	where (select count(*) from Posts a where a.ParentId = q.Id and a.Score > 0) = 0
	and CommunityOwnedDate is null and ClosedDate is null and q.ParentId is null 
	and AcceptedAnswerId is null


	select top 2000 u.Id as [Post Link], 
	(sum(t.[Count]) / 10.0 + us.Reputation / 200.0 + p.Score * 100) as Weight 
	from #unanswered u
	join Posts p on u.Id = p.Id
	join PostTags pt on pt.PostId = u.Id
	join #tags t on t.TagId = pt.TagId  
	join Users us on us.Id = p.OwnerUserId  
	group by u.Id, us.Reputation, p.Score 
	order by Weight desc 
end
go

exec dbo.usp_find_interesting_unanswered_questions @UserId = 545629
go