-- https://data.stackexchange.com/stackoverflow/query/949/what-is-my-accepted-answer-percentage-rate
-- What is my accepted answer percentage rate
-- On avg how often are answers I give, accepted

DECLARE @UserId int;
SET @UserId = (SELECT TOP (1) Id FROM dbo.Users ORDER BY NEWID());

SELECT /* What is my accepted answer percentage rate */
    (CAST(Count(a.Id) AS float) / (SELECT Count(*) FROM Posts WHERE OwnerUserId = @UserId AND PostTypeId = 2) * 100) AS AcceptedPercentage
FROM
    Posts q
  INNER JOIN
    Posts a ON q.AcceptedAnswerId = a.Id
WHERE
    a.OwnerUserId = @UserId
  AND
    a.PostTypeId = 2