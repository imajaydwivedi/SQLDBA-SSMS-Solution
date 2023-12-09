use StackOverflow
go

create or alter procedure dbo.usp_Top_100_Users_that_rarely_upvote
								@MinReputation int, @MinUpvotes int
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/6856/high-standards-top-100-users-that-rarely-upvote
	-- High Standards - Top 100 Users that rarely upvote.
	-- Top 100 Users that rarely upvote in comparison to the estimated amount of upvotes they received (doesn't account for e.g. bounties but should give a sufficient estimation). Useful settings (MinRep, MinUpvotes): (1000, 100), (10000, 0).

	select top 100
	  id as [User Link],
	  round((100.0 * (Reputation/10)) / (Upvotes+1), 2) as [Ratio %],
	  Reputation as Rep, 
	  UpVotes as [+ Votes],
	  DownVotes [- Votes]
	from Users
	where Reputation > @MinReputation
	  and Upvotes > @MinUpvotes
	order by [Ratio %] desc
end
go

exec dbo.usp_Top_100_Users_that_rarely_upvote @MinReputation = 1000, @MinUpvotes = 100
go
exec dbo.usp_Top_100_Users_that_rarely_upvote @MinReputation = 10000, @MinUpvotes = 0
go