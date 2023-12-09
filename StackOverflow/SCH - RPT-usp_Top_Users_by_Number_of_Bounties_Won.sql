use StackOverflow
go

create or alter procedure dbo.usp_Top_Users_by_Number_of_Bounties_Won
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/1080/top-users-by-number-of-bounties-won
	-- Top Users by Number of Bounties Won
	SELECT Top 100
	  Posts.OwnerUserId As [User Link], COUNT(*) As BountiesWon
	FROM Votes
	  INNER JOIN Posts ON Votes.PostId = Posts.Id
	WHERE
	  VoteTypeId=9
	GROUP BY
	  Posts.OwnerUserId
	ORDER BY
	  BountiesWon DESC
end
go

exec dbo.usp_Top_Users_by_Number_of_Bounties_Won
go
