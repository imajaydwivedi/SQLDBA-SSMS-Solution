use StackOverflow
go

create or alter procedure dbo.usp_Rising_stars
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/946/rising-stars-top-50-users-ordered-on-rep-per-day
	-- Rising stars, top 50 users ordered on rep per day
	-- Looking at the duration from when a user created their account till
	-- the last post, who gained the most rep per day

	set nocount on

	DECLARE @endDate date
	SELECT @endDate = max(CreationDate) from Posts

	set nocount off

	SELECT TOP 50
		Id AS [User Link], Reputation, Days,
		Reputation/Days AS RepPerDays
	FROM (
		SELECT *,
			DATEDIFF(DAY, CreationDate, @endDate) as Days
		FROM Users
	) AS UsersAugmented
	WHERE
		Reputation > 5000
	ORDER BY
		RepPerDays DESC
end
go

exec dbo.usp_Rising_stars
go