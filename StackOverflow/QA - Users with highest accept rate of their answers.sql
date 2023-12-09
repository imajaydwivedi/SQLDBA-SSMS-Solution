-- https://data.stackexchange.com/stackoverflow/query/1433/users-with-highest-accept-rate-of-their-answers
/* Does not count self-answers. Shows users with at least @MinAnswers answers.
*/

-- Users with highest accept rate of their answers
-- Does not count self-answers. 
-- Shows users with at least @MinAnswers answers.
USE StackOverflow
go

DECLARE @MinAnswers int = 20
	
SELECT TOP 100 /* Users with highest accept rate of their answers */
  u.Id AS [User Link],
  count(*) AS NumAnswers,
  sum(case when q.AcceptedAnswerId = a.Id then 1 else 0 end) AS NumAccepted,
  (sum(case when q.AcceptedAnswerId = a.Id then 1 else 0 end)*100.0/count(*)) AS AcceptedPercent
FROM Posts a
INNER JOIN Users u ON u.Id = a.OwnerUserId
INNER JOIN Posts q ON a.ParentId = q.Id
WHERE 
  (q.OwnerUserId <> u.Id OR q.OwnerUserId IS NULL)   --no self answers
GROUP BY u.Id
HAVING count(*) >= @MinAnswers
ORDER BY AcceptedPercent DESC, NumAnswers DESC