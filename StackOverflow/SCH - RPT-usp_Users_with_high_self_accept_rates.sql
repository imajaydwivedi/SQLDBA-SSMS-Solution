use StackOverflow
go

create or alter procedure dbo.usp_Users_with_high_self_accept_rates
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/1933/users-with-high-self-accept-rates-and-having-10-answers
	--Users with high self-accept rates (and having > 10 answers)
	-- (the extreme self-learners)
	SELECT 
		TOP 100
		Users.Id AS [User Link],
		(CAST(Count(a.Id) AS float) / CAST((SELECT Count(*) FROM Posts p WHERE p.OwnerUserId = Users.Id AND PostTypeId = 1) AS float) * 100) AS SelfAnswerPercentage
	FROM
		Posts q
	  INNER JOIN 
		Posts a ON q.AcceptedAnswerId = a.Id
	  INNER JOIN
		Users ON Users.Id = q.OwnerUserId
	WHERE 
		q.OwnerUserId = a.OwnerUserId
	GROUP BY
		Users.Id, DisplayName
	HAVING
		Count(a.Id) > 10
	ORDER BY
		SelfAnswerPercentage DESC
end
go

exec dbo.usp_Users_with_high_self_accept_rates
go
