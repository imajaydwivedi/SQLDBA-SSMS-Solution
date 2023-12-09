use StackOverflow
go

create or alter procedure dbo.usp_Quickest_badge_earners @BadgeName nvarchar(80)
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/10418/quickest-badge-earners-v2c
	-- Quickest badge earners V2b
	-- Now addresses the fact that some badges aren't even introduced until a certain date, so some members couldn't have gotten it any sooner since they aren't applied retroactively.
	-- Added 1 plus DateDiff (OBOE)

	DECLARE @firstTime date
	SELECT @firstTime = min(Badges.Date) FROM Badges WHERE Badges.Name = @BadgeName
	;
	WITH BadgeEarners AS (
	   SELECT
		  Users.Id as [User Link],
		  Users.CreationDate as [Member Since],
		  Badges.Date as [Date Won],
		  1+DateDiff(Day, Users.CreationDate, Badges.Date) As [DaysMembership]
	   FROM
		 Badges
		 INNER JOIN Users
		 ON Badges.UserId = Users.Id
	   WHERE
		 Badges.Name = @BadgeName
	)

	SELECT
	   *, DateDiff(Day, @firstTime, [Date Won]) As [DaysSince1st]
	FROM BadgeEarners
	ORDER BY
	   [DaysMembership] ASC
end
go

exec dbo.usp_Quickest_badge_earners @BadgeName = 'teacher'
go