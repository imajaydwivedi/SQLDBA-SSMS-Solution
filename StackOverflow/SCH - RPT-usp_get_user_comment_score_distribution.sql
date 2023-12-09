use StackOverflow
go

create or alter procedure dbo.usp_get_user_comment_score_distribution @UserId int
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/947/my-comment-score-distribution
	-- My Comment Score distribution

	SELECT 
		Count(*) AS CommentCount,
		Score
	FROM 
		Comments
	WHERE 
		UserId = @UserId
	GROUP BY 
		Score
	ORDER BY 
		Score DESC
end
go

exec dbo.usp_get_user_comment_score_distribution @UserId = 545629
go