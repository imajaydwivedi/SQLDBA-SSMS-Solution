-- https://data.stackexchange.com/stackoverflow/query/947/my-comment-score-distribution

DECLARE @UserId int = 4449743
	/* My Comment Score distribution */
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