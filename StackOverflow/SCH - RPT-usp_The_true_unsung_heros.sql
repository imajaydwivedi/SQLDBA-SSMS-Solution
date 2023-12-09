use StackOverflow
go

create or alter procedure dbo.usp_The_true_unsung_heros
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/6607/the-true-unsung-heros
	-- The true unsung heros
	-- List of users with more than 10 zero score answers, ordered by ratio of zero to non zero score
	select X.*, u.Reputation from (
	  select a.OwnerUserId [User Link], 
	  sum(case when a.Score = 0 then 0 else 1 end) as [Non Zero Score Answers],  
	  sum(case when a.Score = 0 then 1 else 0 end) as [Zero Score Answers]
	from Posts q
	join Posts a on a.Id = q.AcceptedAnswerId 
	where a.CommunityOwnedDate is null and a.OwnerUserId is not null
	 and a.OwnerUserId <> isnull(q.OwnerUserId,-1)
	group by a.OwnerUserId
	having sum(case when a.Score = 0 then 1 else 0 end) > 10
	) as X 
	join Users u on u.Id = [User Link]
	order by ([Zero Score Answers]+ 0.0) / ([Zero Score Answers]+ [Non Zero Score Answers]+ 0.0) desc
end
go

exec dbo.usp_The_true_unsung_heros
go
