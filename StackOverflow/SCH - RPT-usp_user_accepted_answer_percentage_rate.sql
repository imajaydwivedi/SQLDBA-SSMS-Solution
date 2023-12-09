use StackOverflow
go

create or alter procedure dbo.usp_user_accepted_answer_percentage_rate @UserId int
as
begin
	-- What is my accepted answer percentage rate
	-- On avg how often are answers I give, accepted

	SELECT 
		(CAST(Count(a.Id) AS float) / (SELECT Count(*) FROM Posts WHERE OwnerUserId = @UserId AND PostTypeId = 2) * 100) AS AcceptedPercentage
	FROM
		Posts q
	  INNER JOIN
		Posts a ON q.AcceptedAnswerId = a.Id
	WHERE
		a.OwnerUserId = @UserId
	  AND
		a.PostTypeId = 2
end
go

exec dbo.usp_user_accepted_answer_percentage_rate @UserId = 545629
go