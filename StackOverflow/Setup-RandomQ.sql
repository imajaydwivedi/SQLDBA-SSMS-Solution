/*	Using Stack Overflow Queries to Generate Workloads
	--	https://www.brentozar.com/archive/2016/08/dell-dba-days-prep-using-stackexchange-queries-generate-workloads/
	--	https://gist.github.com/BrentOzar/12b8ac33a67f02f413d30529caff5676
	https://github.com/ErikEJ/SqlQueryStress

	https://www.brentozar.com/archive/2019/04/free-sql-server-load-testing-tools/
	https://www.brentozar.com/archive/2017/02/simulating-workload-ostress-agent-jobs/
*/
/*
restore database StackOverflow from disk = N'G:\StackOverflow_122018_Full_OriginalCopy.bak' 
	with stats=3
	,move 'StackOverflow_1' to 'F:\MSSQL14.SQL2017\MSSQL\DATA\StackOverflow_1.mdf'
	,move 'StackOverflow_2' to 'F:\MSSQL14.SQL2017\MSSQL\DATA\StackOverflow_2.mdf'
	,move 'StackOverflow_3' to 'F:\MSSQL14.SQL2017\MSSQL\DATA\StackOverflow_3.mdf'
	,move 'StackOverflow_4' to 'F:\MSSQL14.SQL2017\MSSQL\DATA\StackOverflow_4.mdf'
	,move 'StackOverflow_log' to 'E:\MSSQL14.SQL2017\MSSQL\Log\StackOverflow_log.ldf'
GO


"C:\Program Files\Microsoft Corporation\RMLUtils\ostress.exe" --Path to ostress executable
-SNADAULTRA\SQL2016C --Server name (note that this is how you access a named instance)
-d"StackOverflow" --Database name
-n20 --How many simultaneous sessions you want to run your query
-r10 --How many iterations they should each perform
-q --Quiet mode; doesn't return rows
-Q"EXEC dbo.usp_RandomQ" --Query you want to run
-o"C:\temp\DBA_LoadTest_StackOverflow" --Logging folder
*/
USE StackOverflow;
GO

IF DB_NAME() <> 'StackOverflow'
  RAISERROR(N'Oops! For some reason the StackOverflow database does not exist here.', 20, 1) WITH LOG;
GO

CREATE OR ALTER FUNCTION dbo.make_parallel()       
RETURNS TABLE AS        
RETURN        
(        
    WITH        
    a(x) AS        
    (        
        SELECT        
            a0.*        
        FROM        
        (        
            VALUES        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1),        
                (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1), (1)        
        ) AS a0(x)        
    ),        
    b(x) AS        
    (        
        SELECT TOP(9223372036854775807)        
            1        
        FROM        
            a AS a1,        
            a AS a2,        
            a AS a3,        
            a AS a4        
        WHERE        
            a1.x % 2 = 0
    )        
    SELECT        
        SUM(b1.x) AS x        
    FROM        
        b AS b1        
    HAVING        
        SUM(b1.x) IS NULL        
)        
GO

IF OBJECT_ID('dbo.rpt_TopUsers_ByLocation') IS NULL
  EXEC ('CREATE PROCEDURE dbo.rpt_TopUsers_ByLocation AS RETURN 0;')
GO

ALTER PROC dbo.rpt_TopUsers_ByLocation
    @Location NVARCHAR(100), @StartDate DATE, @EndDate DATE AS
BEGIN
/*
-- https://www.youtube.com/watch?v=IVqvwNlwXuI
exec dbo.rpt_TopUsers_ByLocation
            @Location = N'Reading, United Kingdom',
            @StartDate = '2011-09-01', @EndDate = '2011-10-01'
*/
    SELECT TOP 1000 u.Reputation, u.DisplayName, u.AboutMe,
            COUNT(p.Id) AS PostsCount,
            SUM(p.Score) AS PostsScore,
            SUM(c.Score) AS CommentsScore
        FROM dbo.Users u
            LEFT OUTER JOIN dbo.Posts p ON u.Id = p.OwnerUserId AND p.CreationDate BETWEEN @StartDate AND @EndDate
            LEFT OUTER JOIN dbo.Comments c ON u.Id = c.UserId AND c.CreationDate BETWEEN @StartDate AND @EndDate
        WHERE u.Location = @Location
        GROUP BY u.Reputation, u.DisplayName, u.AboutMe
        ORDER BY SUM(p.Score) DESC
END
GO

CREATE OR ALTER PROC ##rpt_TopUsers_ByLocation
    @Location NVARCHAR(100), @StartDate DATE, @EndDate DATE AS
BEGIN
/*
-- https://www.youtube.com/watch?v=IVqvwNlwXuI
exec ##rpt_TopUsers_ByLocation
            @Location = N'Reading, United Kingdom',
            @StartDate = '2011-09-01', @EndDate = '2011-10-01'
*/
    /*
    SELECT TOP 1000 u.Reputation, u.DisplayName, u.AboutMe,
            SUM(p.Score) AS PostsScore,
            SUM(c.Score) AS CommentsScore
        FROM dbo.Users u
            LEFT OUTER JOIN dbo.Posts p ON u.Id = p.OwnerUserId AND p.CreationDate BETWEEN @StartDate AND @EndDate
            LEFT OUTER JOIN dbo.Comments c ON u.Id = c.UserId AND c.CreationDate BETWEEN @StartDate AND @EndDate
        WHERE u.Location = @Location
        GROUP BY u.Reputation, u.DisplayName, u.AboutMe
        ORDER BY SUM(p.Score) DESC
        OPTION (QUERYTRACEON 8671); -- best plan
        OPTION (QUERYTRACEON 8649); -- parallel plan
    */

    ;WITH MatchingUsers as (
        -- Use a "CTE+TOP+SORT" technique to force rebalacing of rows from dbo.Users.
           -- Check for Parallelism (Gather Streams & Distribute Steams) in the execution plan to confirm that it worked.
        SELECT TOP (2147483647) u.Id, u.Reputation, u.DisplayName, u.AboutMe
        FROM dbo.Users u
        WHERE u.Location = @Location
        ORDER BY u.DisplayName
    )
    SELECT x.*
    -- Use this Inline TVF to force parallelism, and then CROSS APPLY the actual query to get the result.
       -- After this, the query that was single threaded should now be parallel, and you should see multiple threads in the execution plan.
    FROM dbo.make_parallel() as mp
    CROSS APPLY (
    SELECT TOP 1000 u.Reputation, u.DisplayName, u.AboutMe,
            COUNT(p.Id) AS PostsCount,
            SUM(p.Score) AS PostsScore,
            SUM(c.Score) AS CommentsScore
        FROM MatchingUsers u
            LEFT OUTER JOIN dbo.Posts p ON u.Id = p.OwnerUserId AND p.CreationDate BETWEEN @StartDate AND @EndDate
            LEFT OUTER JOIN dbo.Comments c ON u.Id = c.UserId AND c.CreationDate BETWEEN @StartDate AND @EndDate
        WHERE 1=1
        GROUP BY u.Reputation, u.DisplayName, u.AboutMe
        ORDER BY SUM(p.Score) DESC
    ) AS x;
END
GO

IF OBJECT_ID('dbo.usp_Q7521') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_Q7521 AS RETURN 0;')
GO

ALTER PROC dbo.usp_Q7521 @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/7521/how-unsung-am-i */

-- How Unsung am I?
-- Zero and non-zero accepted count. Self-accepted answers do not count.

select
    count(a.Id) as [Accepted Answers],
    sum(case when a.Score = 0 then 0 else 1 end) as [Scored Answers],  
    sum(case when a.Score = 0 then 1 else 0 end) as [Unscored Answers],
    sum(CASE WHEN a.Score = 0 then 1 else 0 end)*1000 / count(a.Id) / 10.0 as [Percentage Unscored]
from
    Posts q
  inner join
    Posts a
  on a.Id = q.AcceptedAnswerId
where
      a.CommunityOwnedDate is null
  and a.OwnerUserId = @UserId
  and q.OwnerUserId != @UserId
  and a.PostTypeId = 2
END
GO


IF OBJECT_ID('dbo.usp_Q36660') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_Q36660 AS RETURN 0;')
GO

ALTER PROC dbo.usp_Q36660 @Useless INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/36660/most-down-voted-questions */

select top 20 count(v.PostId) as 'Vote count', v.PostId AS [Post Link],p.Body
from Votes v 
inner join Posts p on p.Id=v.PostId
where PostTypeId = 1 and v.VoteTypeId=3
group by v.PostId,p.Body
order by 'Vote count' desc

END
GO


IF OBJECT_ID('dbo.usp_Q949') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_Q949 AS RETURN 0;')
GO

ALTER PROC dbo.usp_Q949 @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/949/what-is-my-accepted-answer-percentage-rate */

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

END
GO



IF OBJECT_ID('dbo.usp_Q466') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_Q466 AS RETURN 0;')
GO

ALTER PROC dbo.usp_Q466 @Useless INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/466/most-controversial-posts-on-the-site */
set nocount on 

declare @VoteStats table (PostId int, up int, down int) 

insert @VoteStats
select
    PostId, 
    up = sum(case when VoteTypeId = 2 then 1 else 0 end), 
    down = sum(case when VoteTypeId = 3 then 1 else 0 end)
from Votes
where VoteTypeId in (2,3)
group by PostId

set nocount off


select top 100 p.Id as [Post Link] , up, down from @VoteStats 
join Posts p on PostId = p.Id
where down > (up * 0.5) and p.CommunityOwnedDate is null and p.ClosedDate is null
order by up desc
END
GO




IF OBJECT_ID('dbo.usp_Q947') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_Q947 AS RETURN 0;')
GO

ALTER PROC dbo.usp_Q947 @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/947/my-comment-score-distribution */

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
END
GO




IF OBJECT_ID('dbo.usp_Q3160') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_Q3160 AS RETURN 0;')
GO

ALTER PROC dbo.usp_Q3160 @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/3160/jon-skeet-comparison */

with fights as (
  select myAnswer.ParentId as Question,
   myAnswer.Score as MyScore,
   jonsAnswer.Score as JonsScore
  from Posts as myAnswer
  inner join Posts as jonsAnswer
   on jonsAnswer.OwnerUserId = 22656 and myAnswer.ParentId = jonsAnswer.ParentId
  where myAnswer.OwnerUserId = @UserId and myAnswer.PostTypeId = 2
)

select
  case
   when MyScore > JonsScore then 'You win'
   when MyScore < JonsScore then 'Jon wins'
   else 'Tie'
  end as 'Winner',
  Question as [Post Link],
  MyScore as 'My score',
  JonsScore as 'Jon''s score'
from fights;
END
GO




IF OBJECT_ID('dbo.usp_Q6627') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_Q6627 AS RETURN 0;')
GO

ALTER PROC dbo.usp_Q6627 @Useless INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/6627/top-50-most-prolific-editors */

-- Top 50 Most Prolific Editors
-- Shows the top 50 post editors, where the user was the most recent editor
-- (meaning the results are conservative compared to the actual number of edits).

SELECT TOP 50
    Id AS [User Link],
    (
        SELECT COUNT(*) FROM Posts
        WHERE
            PostTypeId = 1 AND
            LastEditorUserId = Users.Id AND
            OwnerUserId != Users.Id
    ) AS QuestionEdits,
    (
        SELECT COUNT(*) FROM Posts
        WHERE
            PostTypeId = 2 AND
            LastEditorUserId = Users.Id AND
            OwnerUserId != Users.Id
    ) AS AnswerEdits,
    (
        SELECT COUNT(*) FROM Posts
        WHERE
            LastEditorUserId = Users.Id AND
            OwnerUserId != Users.Id
    ) AS TotalEdits
    FROM Users
    ORDER BY TotalEdits DESC

END
GO






IF OBJECT_ID('dbo.usp_Q6772') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_Q6772 AS RETURN 0;')
GO

ALTER PROC dbo.usp_Q6772 @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/6772/stackoverflow-rank-and-percentile */

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

END
GO









IF OBJECT_ID('dbo.usp_Q6856') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_Q6856 AS RETURN 0;')
GO

ALTER PROC dbo.usp_Q6856 @MinReputation INT, @Upvotes INT = 100 AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/6856/high-standards-top-100-users-that-rarely-upvote */

select top 100
  Id as [User Link],
  round((100.0 * (Reputation/10)) / (UpVotes+1), 2) as [Ratio %],
  Reputation as Rep, 
  UpVotes as [+ Votes],
  DownVotes [- Votes]
from Users
where Reputation > @MinReputation
  and UpVotes > @Upvotes
order by [Ratio %] desc

END
GO




IF OBJECT_ID('dbo.usp_Q952') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_Q952 AS RETURN 0;')
GO

ALTER PROC dbo.usp_Q952 @Useless INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/952/top-500-answerers-on-the-site */

SELECT 
    TOP 500
    Users.Id as [User Link],
    Count(Posts.Id) AS Answers,
    CAST(AVG(CAST(Score AS float)) as numeric(6,2)) AS [Average Answer Score]
FROM
    Posts
  INNER JOIN
    Users ON Users.Id = OwnerUserId
WHERE 
    PostTypeId = 2 and CommunityOwnedDate is null and ClosedDate is null
GROUP BY
    Users.Id, DisplayName
HAVING
    Count(Posts.Id) > 10
ORDER BY
    [Average Answer Score] DESC

END
GO







IF OBJECT_ID('dbo.usp_Q975') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_Q975 AS RETURN 0;')
GO

ALTER PROC dbo.usp_Q975 @Useless INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/975/users-with-more-than-one-duplicate-account-and-a-more-than-1000-reputation-in-agg */

-- Users with more than one duplicate account and a more that 1000 reputation in aggregate
-- A list of users that have duplicate accounts on site, based on the EmailHash and lots of reputation is riding on it

SELECT 
    u1.EmailHash,
    Count(u1.Id) AS Accounts,
    (
        SELECT Cast(u2.Id AS varchar) + ' (' + u2.DisplayName + ' ' + Cast(u2.Reputation as varchar) + '), ' 
        FROM Users u2 
        WHERE u2.EmailHash = u1.EmailHash order by u2.Reputation desc FOR XML PATH ('')) AS IdsAndNames
FROM
    Users u1
WHERE
    u1.EmailHash IS NOT NULL
    and (select sum(u3.Reputation) from Users u3 where u3.EmailHash = u1.EmailHash) > 1000  
    and (select count(*) from Users u3 where u3.EmailHash = u1.EmailHash and Reputation > 10) > 1
GROUP BY
    u1.EmailHash
HAVING
    Count(u1.Id) > 1
ORDER BY 
    Accounts DESC

END
GO




IF OBJECT_ID('dbo.usp_Q8116') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_Q8116 AS RETURN 0;')
GO

ALTER PROC dbo.usp_Q8116 @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/8116/my-money-for-jam */

-- My Money for Jam
-- My Non Community Wiki Posts that earn the most Passive Reputation.
-- Reputation gained in the first 15 days of post is ignored,
-- all reputation after that is considered passive reputation.
-- Post must be at least 60 Days old.

set nocount on

declare @latestDate datetime
select @latestDate = max(CreationDate) from Posts
declare @ignoreDays numeric = 15
declare @minAgeDays numeric = @ignoreDays * 4

-- temp table moded from http://odata.stackexchange.com/stackoverflow/s/87
declare @VoteStats table (PostId int, up int, down int, CreationDate datetime)
insert @VoteStats
select
    p.Id,
    up = sum(case when VoteTypeId = 2 then
        case when p.ParentId is null then 5 else 10 end
        else 0 end),
    down = sum(case when VoteTypeId = 3 then 2 else 0 end),
    p.CreationDate
from Votes v join Posts p on v.PostId = p.Id
where v.VoteTypeId in (2,3)
and OwnerUserId = @UserId
and p.CommunityOwnedDate is null
and datediff(day, p.CreationDate, v.CreationDate) > @ignoreDays
and datediff(day, p.CreationDate, @latestDate) > @minAgeDays
group by p.Id, p.CreationDate, p.ParentId

set nocount off

select top 100 PostId as [Post Link],
  convert(decimal(10,2), up - down)/(datediff(day, vs.CreationDate, @latestDate) - @ignoreDays) as [Passive Rep Per Day],
  (up - down) as [Passive Rep],
  up as [Passive Up Reputation],
  down as [Passive Down Reputation],
  datediff(day, vs.CreationDate, @latestDate) - @ignoreDays as [Days Counted]
from @VoteStats vs
order by [Passive Rep Per Day] desc


END
GO









IF OBJECT_ID('dbo.usp_RandomQ') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_RandomQ AS RETURN 0;')
GO

ALTER PROCEDURE dbo.usp_RandomQ WITH RECOMPILE
AS
SET NOCOUNT ON

DECLARE @Id INT = CAST(RAND() * 10000000 AS INT);

IF @Id % 12 = 0
    EXEC dbo.usp_Q3160 @Id
ELSE IF @Id % 11 = 0
    EXEC dbo.usp_Q36660 @Id
ELSE IF @Id % 10 = 0
    EXEC dbo.usp_Q466 @Id
--ELSE IF @Id % 9 = 0
--    EXEC dbo.usp_Q6627 @Id
ELSE IF @Id % 8 = 0
    EXEC dbo.usp_Q6772 @Id
ELSE IF @Id % 7 = 0
    EXEC dbo.usp_Q6856 @Id
ELSE IF @Id % 6 = 0
    EXEC dbo.usp_Q7521 @Id
ELSE IF @Id % 5 = 0
    EXEC dbo.usp_Q8116 @Id
ELSE IF @Id % 4 = 0
    EXEC dbo.usp_Q947 @Id
ELSE IF @Id % 3 = 0
    EXEC dbo.usp_Q949 @Id
ELSE IF @Id % 2 = 0
    EXEC dbo.usp_Q952 @Id
ELSE
	EXEC dbo.usp_Q975 @Id
GO
--EXEC dbo.usp_RandomQ;


