use StackOverflow
go

create or alter procedure dbo.usp_user_StackOverflow_Rank_and_Percentile @UserId int
as
begin
	-- StackOverflow Rank and Percentile

	WITH Rankings AS (
	SELECT Id, Ranking = ROW_NUMBER() OVER(ORDER BY Reputation DESC)
	FROM Users
	)
	,Counts AS (
	SELECT Count = COUNT(*)
	FROM Users
	WHERE Reputation > 100
	)
	SELECT Id, Ranking, CAST(Ranking AS decimal(20, 5)) / (SELECT Count FROM Counts) AS Percentile
	FROM Rankings
	WHERE Id = @UserId
end
go

exec dbo.usp_user_StackOverflow_Rank_and_Percentile @UserId = 545629
go
