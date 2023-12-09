-- https://data.stackexchange.com/stackoverflow/query/6772/stackoverflow-rank-and-percentile

DECLARE @Userid int = 17174;

-- StackOverflow Rank and Percentile
WITH Rankings AS ( /* -- StackOverflow Rank and Percentile */
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