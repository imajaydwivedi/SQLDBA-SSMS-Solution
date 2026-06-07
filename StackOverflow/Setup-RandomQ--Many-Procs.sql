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

if OBJECT_ID('dbo.Tags') is null
BEGIN
    --drop table dbo.Tags;
    CREATE TABLE dbo.Tags
    (
        Id int IDENTITY(1,1) PRIMARY KEY,
        TagName varchar(200) UNIQUE
    );
END
go

if OBJECT_ID('dbo.Tags') is not null and not exists (select 1 from dbo.Tags)
begin
    print 'Populating dbo.Tags table...';

    declare @_BatchSize bigint = 1000;
    declare @_BatchCount bigint = ((select count(*) from dbo.Posts)/@_BatchSize)+1;
    declare @_CurrentBatch bigint = 1;
    declare @_StartId bigint = 0;
    declare @_EndId bigint = 0;

    while @_CurrentBatch <= @_BatchCount
    begin
        set @_StartId = (@_CurrentBatch-1)*@_BatchSize;
        set @_EndId = @_StartId + @_BatchSize - 1;
        print 'Processing "dbo.Tags" batch ' + cast(@_CurrentBatch as varchar) + ' of ' + cast(@_BatchCount as varchar);
        print '  Processing Id '+convert(varchar(10),@_StartId)+' to '+convert(varchar(10), @_EndId);

        ;WITH tags AS
        (
            SELECT TagName = ltrim(rtrim(value))
            FROM dbo.Posts p
            CROSS APPLY STRING_SPLIT(TRANSLATE(p.Tags, '<>', '  '),' ')
            WHERE p.Tags IS NOT NULL
            and p.Id BETWEEN @_StartId AND @_EndId
        )
        INSERT dbo.Tags (TagName)
        SELECT DISTINCT TagName
        FROM tags
        WHERE TagName <> ''
        AND NOT EXISTS
        (
            SELECT 1
            FROM dbo.Tags t
            WHERE t.TagName = tags.TagName
        );

        set @_CurrentBatch += 1;
    end
end
go


if OBJECT_ID('dbo.PostTags') is null
begin
    create table dbo.PostTags
    (	PostId int not null,
	    TagId int not null,
	    constraint pk_PostTags primary key (PostId, Tagid),
	    constraint fk_PostTags__PostId foreign key (PostId) references dbo.Posts (Id),
	    constraint fk_PostTags__TagId foreign key (TagId) references dbo.Tags (Id)
    );
end
go

alter table dbo.PostTags nocheck constraint fk_PostTags__PostId;
alter table dbo.PostTags nocheck constraint fk_PostTags__TagId;
GO

if object_id('dbo.PostTags') is not null and not exists (select 1 from dbo.PostTags)
begin
    print 'Populating dbo.PostTags table...';

    declare @_BatchSize bigint = 1000;
    declare @_BatchCount bigint = ((select count(*) from dbo.Posts)/@_BatchSize)+1;
    declare @_CurrentBatch bigint = 1;
    declare @_StartId bigint = 0;
    declare @_EndId bigint = 0;

    while @_CurrentBatch <= @_BatchCount
    begin
        set @_StartId = (@_CurrentBatch-1)*@_BatchSize;
        set @_EndId = @_StartId + @_BatchSize - 1;
        print 'Processing "dbo.PostTags" batch ' + cast(@_CurrentBatch as varchar) + ' of ' + cast(@_BatchCount as varchar);
        print '  Processing Id '+convert(varchar(10),@_StartId)+' to '+convert(varchar(10), @_EndId);

        ;WITH tags AS
        (
            SELECT distinct PostId = p.Id, TagName = ltrim(rtrim(ss.value))
            FROM dbo.Posts p
            CROSS APPLY STRING_SPLIT(TRANSLATE(p.Tags, '<>', '  '),' ') as ss
            WHERE p.Tags IS NOT NULL
            and p.Id BETWEEN @_StartId AND @_EndId
            and ltrim(rtrim(ss.value)) <> ''
        )
        INSERT dbo.PostTags (PostId, TagId)
        select tt.PostId, TagId = t.Id
        from dbo.Tags t
        join tags tt on tt.TagName = ltrim(rtrim(t.TagName));

        set @_CurrentBatch += 1;
    end
end
go

alter table dbo.PostTags with check check constraint fk_PostTags__PostId;
alter table dbo.PostTags with check check constraint fk_PostTags__TagId;
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

CREATE OR ALTER PROCEDURE dbo.usp_Q785
    @UserId INT
AS
BEGIN
    /* Example usage:
    EXEC dbo.usp_Q785 @UserId = 12345;

    This procedure returns a list of tags and the count of upvotes
    received by the specified user for each tag.
    */

    SET NOCOUNT ON;

    SELECT
        t.TagName,
        COUNT(*) AS UpVotes
    FROM dbo.Tags t
    INNER JOIN dbo.PostTags pt ON pt.TagId = t.id
    INNER JOIN dbo.Posts p ON p.ParentId = pt.PostId
    INNER JOIN dbo.Votes v ON v.PostId = p.Id
    WHERE p.OwnerUserId = @UserId
      AND v.VoteTypeId = 2 -- 2 represents UpVotes
    GROUP BY t.TagName
    ORDER BY UpVotes DESC;
END
GO

IF OBJECT_ID('dbo.usp_Q7521') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_Q7521 @Useless INT AS RETURN 0;')
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
  EXEC ('CREATE PROCEDURE dbo.usp_Q36660 @Useless INT AS RETURN 0;')
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
  EXEC ('CREATE PROCEDURE dbo.usp_Q949 @Useless INT AS RETURN 0;')
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
  EXEC ('CREATE PROCEDURE dbo.usp_Q466 @Useless INT AS RETURN 0;')
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
  EXEC ('CREATE PROCEDURE dbo.usp_Q947 @Useless INT AS RETURN 0;')
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
  EXEC ('CREATE PROCEDURE dbo.usp_Q3160 @Useless INT AS RETURN 0;')
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
  EXEC ('CREATE PROCEDURE dbo.usp_Q6627 @Useless INT AS RETURN 0;')
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
  EXEC ('CREATE PROCEDURE dbo.usp_Q6772 @Useless INT AS RETURN 0;')
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
  EXEC ('CREATE PROCEDURE dbo.usp_Q6856 @Useless INT AS RETURN 0;')
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
  EXEC ('CREATE PROCEDURE dbo.usp_Q952 @Useless INT AS RETURN 0;')
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
  EXEC ('CREATE PROCEDURE dbo.usp_Q975 @Useless INT AS RETURN 0;')
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
  EXEC ('CREATE PROCEDURE dbo.usp_Q8116 @Useless INT AS RETURN 0;')
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


CREATE OR ALTER PROCEDURE dbo.usp_Q4038 @UserId INT AS
BEGIN

SET NOCOUNT ON;
	/*
	Example Execution:
	EXEC dbo.usp_Q4038 @UserId = <value>;
	*/
-- https://data.stackexchange.com/stackoverflow/query/4038/find-interesting-unanswered-questions
-- Find interesting unanswered questions
-- Looks at unanswered questions in your top 20 tags and sorts them by
-- a combined weight which takes into account: score, askers reputation and how
-- well you do on that particular tag


create table #tags (TagId int, [Count] int)

insert #tags
SELECT TOP 20
    TagId,
    COUNT(*) AS UpVotes
FROM Tags
    INNER JOIN PostTags ON PostTags.TagId = Tags.id
    INNER JOIN Posts ON Posts.ParentId = PostTags.PostId
    INNER JOIN Votes ON Votes.PostId = Posts.Id and VoteTypeId = 2
WHERE
    Posts.OwnerUserId = @UserId
GROUP BY TagId
ORDER BY UpVotes DESC


create table #unanswered (Id int primary key)

insert #unanswered
select q.Id  from Posts q
where (select count(*) from Posts a where a.ParentId = q.Id and a.Score > 0) = 0
and CommunityOwnedDate is null and ClosedDate is null and q.ParentId is null
and AcceptedAnswerId is null


select top 2000 u.Id as [Post Link],
(sum(t.[Count]) / 10.0 + us.Reputation / 200.0 + p.Score * 100) as Weight
from #unanswered u
join Posts p on u.Id = p.Id
join PostTags pt on pt.PostId = u.Id
join #tags t on t.TagId = pt.TagId
join Users us on us.Id = p.OwnerUserId
group by u.Id, us.Reputation, p.Score
order by Weight desc
END
GO



CREATE OR ALTER PROCEDURE dbo.usp_Q2357 @UserId INT AS
BEGIN

SET NOCOUNT ON;
	/*
	Example Execution:
	EXEC dbo.usp_Q2357 @UserId = <value>;
	*/
-- https://data.stackexchange.com/stackoverflow/query/2357/how-many-upvotes-do-i-have-towards-tag-specialist-badges


SELECT TOP 20 /* How many upvotes do I have towards tag-specialist badges */
    TagName,
    COUNT(*) AS UpVotes
FROM Tags
    INNER JOIN PostTags ON PostTags.TagId = Tags.id
    INNER JOIN Posts ON Posts.ParentId = PostTags.PostId
    INNER JOIN Votes ON Votes.PostId = Posts.Id and VoteTypeId = 2
WHERE
    Posts.OwnerUserId = @UserId
    AND Posts.CommunityOwnedDate IS NULL
GROUP BY TagName
ORDER BY UpVotes DESC
END
GO


CREATE OR ALTER PROCEDURE dbo.usp_Q951 @Useless INT AS
BEGIN

SET NOCOUNT ON;
	/*
	Example Execution:
	EXEC dbo.usp_Q951;
	*/
-- https://data.stackexchange.com/stackoverflow/query/951/low-views-high-votes-yet-unanswered

-- Enter Query Title
-- Enter Query Description
select /* Low views, high votes yet unanswered */
		top 500 Id as [Post Link], Score, ViewCount from Posts
where Score > 2 and ViewCount <> 0 and ParentId is null and AcceptedAnswerId is null
order by ViewCount asc
END
GO



CREATE OR ALTER PROCEDURE dbo.usp_Q1433 @MinAnswers INT AS
BEGIN

SET NOCOUNT ON;
	/*
	Example Execution:
	EXEC dbo.usp_Q1433 @MinAnswers = <value>;
	*/
-- https://data.stackexchange.com/stackoverflow/query/1433/users-with-highest-accept-rate-of-their-answers
/* Does not count self-answers. Shows users with at least @MinAnswers answers.
*/

-- Users with highest accept rate of their answers
-- Does not count self-answers.
-- Shows users with at least @MinAnswers answers.


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
END
GO



create or alter procedure dbo.usp_Q7672 @Useless INT AS
begin

	/*
	Example Execution:
	EXEC dbo.usp_Q7672;
	*/
-- https://data.stackexchange.com/stackoverflow/query/7672/bounties-and-questions-by-month
	-- Bounties and Questions by Month
	-- Computes the number of bounties awarded and the total bounty amount awarded each month, along with the number of questions asked.
	select Isnull(V.Year, P.Year), Isnull(V.Month, P.Month), V.Bounties, V.Amount,
	P.Questions
	FROM
	(
	select
	datepart(year, Posts.CreationDate) Year,
	datepart(month, Posts.CreationDate) Month,
	count(Posts.Id) Questions
	from Posts
	where PostTypeid = 1 -- 1 = Question
	group by datepart(year, Posts.CreationDate), datepart(month, Posts.CreationDate)
	) AS P
	left JOIN
	(
	select
	datepart(year, Votes.CreationDate) Year,
	datepart(month, Votes.CreationDate) Month,
	count(Votes.Id) Bounties,
	sum(Votes.BountyAmount) Amount
	from Votes
	where VoteTypeId = 9 -- 9 = BountyAwarded
	group by datepart(year, Votes.CreationDate), datepart(month, Votes.CreationDate)
	) AS V
	ON P.Year = V.Year AND P.Month = V.Month
	order by P.Year, P.Month
end
GO



create or alter procedure dbo.usp_Q1075286 @Useless INT AS
begin

	/*
	Example Execution:
	EXEC dbo.usp_Q1075286;
	*/
-- https://data.stackexchange.com/stackoverflow/query/1075286/duplicate-questions-count-per-month
	-- Duplicate Questions Count per Month
	/*
	This query returns the duplicate questions' count per month
	Author: Issa Moradnejad
	*/
	SELECT date1, count(id) as cnt
	FROM (

	  SELECT
		FORMAT (d.CreationDate, 'yy-MM') as [date1],
		(d.Id) as id
	  FROM Posts d  -- d=duplicate
		LEFT JOIN PostHistory ph ON ph.PostId = d.Id
		LEFT JOIN PostLinks pl ON pl.PostId = d.Id
		LEFT JOIN Posts o ON o.Id = pl.RelatedPostId  -- o=original
	  WHERE
		d.PostTypeId = 1  -- 1=Question
		AND pl.LinkTypeId = 3  -- 3=duplicate
		AND ph.PostHistoryTypeId = 10  -- 10=Post Closed

	  ) as t1
	group by date1
	order by date1
end
GO



create or alter procedure dbo.usp_Q1256 @Useless INT AS
begin

	/*
	Example Execution:
	EXEC dbo.usp_Q1256;
	*/
-- https://data.stackexchange.com/stackoverflow/query/1256/most-and-least-dangerous-tags-to-answer-among-the-tags-with-1000-questions
	-- Most and least dangerous tags to answer (among the tags with 1000+ questions)
	-- This query shows the number of upvotes, downvotes and D/U ratio for the answers to the most common tags
	WITH    q AS
	(
	SELECT  t.*,
			(
			SELECT  COUNT(*) AS cnt
			FROM    posttags pt
			JOIN    posts pp
			ON      pp.id = pt.postid
			JOIN    posts pa
			ON      pa.parentid = pp.id
			JOIN    votes v
			ON      v.postid = pa.id
			WHERE   pt.tagid = t.id
					AND v.votetypeid = 2
			) AS upvotes,
			(
			SELECT  COUNT(*) AS cnt
			FROM    posttags pt
			JOIN    posts pp
			ON      pp.id = pt.postid
			JOIN    posts pa
			ON      pa.parentid = pp.id
			JOIN    votes v
			ON      v.postid = pa.id
			WHERE   pt.tagid = t.id
					AND v.votetypeid = 3
			) AS downvotes
	FROM    Tags t
	CROSS APPLY
			(
			SELECT  COUNT(*) AS cnt
			FROM    PostTags pt
			WHERE   pt.tagid = t.id
			HAVING  COUNT(*) >= 1000
			) pt
	)
	SELECT  tagname AS [Tags], upvotes AS [Upvotes], downvotes AS [Downvotes], ROUND(100.0 * downvotes / NULLIF(upvotes, 0), 2) AS [D/U ratio]
	FROM    q
	ORDER BY
			4 DESC
end
GO



create or alter procedure dbo.usp_Q877 @Useless INT AS
begin
	/*
	Example Execution:
	EXEC dbo.usp_Q877;
	*/
-- https://data.stackexchange.com/stackoverflow/query/877/posts-containing-a-very-short-title
	-- Posts containing a very short title
	-- Posts containing a body that is less than 5 chars long

	select Id as [Post Link], Body, Score from Posts where Len(Title) < 12 and ParentId is null
end
GO



create or alter procedure dbo.usp_Q886 @Useless INT AS
begin

	/*
	Example Execution:
	EXEC dbo.usp_Q886;
	*/
-- https://data.stackexchange.com/stackoverflow/query/886/posts-with-many-thank-you-answers
	-- Posts with many "thank you" answers
	-- Looking at posts shorter than 200 with the text `hank` somewhere in it
	 select
	   ParentId as [Post Link],
	   count(id)
	from posts
	where posttypeid = 2 and len(body) <= 200
	  and (body like '%hank%')
	group by parentid
	having count(id) > 1
	order by count(id) desc;
end
GO



create or alter procedure dbo.usp_Q1075285 @Useless INT AS
begin

	/*
	Example Execution:
	EXEC dbo.usp_Q1075285;
	*/
-- https://data.stackexchange.com/stackoverflow/query/1075285/questions-count-by-month
	-- Questions Count by Month
	SELECT date1, count(id) as cnt
	FROM (

	  SELECT
		FORMAT (d.CreationDate, 'yy-MM') as [date1],
		(d.Id) as id
	  FROM Posts d  -- d=duplicate
		LEFT JOIN PostHistory ph ON ph.PostId = d.Id
		LEFT JOIN PostLinks pl ON pl.PostId = d.Id
		LEFT JOIN Posts o ON o.Id = pl.RelatedPostId  -- o=original
	  WHERE
		d.PostTypeId = 1  -- 1=Question

	  ) as t1
	group by date1
	order by date1
end
GO



create or alter procedure dbo.usp_Q10418 @BadgeName nvarchar(80)
as
begin

	/*
	Example Execution:
	EXEC dbo.usp_Q10418 @BadgeName = <value>;
	*/
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
GO



create or alter procedure dbo.usp_Q946 @Useless INT AS
begin

	/*
	Example Execution:
	EXEC dbo.usp_Q946;
	*/
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
GO



create or alter procedure dbo.usp_Q6607 @Useless INT AS
begin

	/*
	Example Execution:
	EXEC dbo.usp_Q6607;
	*/
-- https://data.stackexchange.com/stackoverflow/query/6607/the-true-unsung-heros
	-- The true unsung heros
	-- List of users with more than 10 zero score answers, ordered by ratio of zero to non zero score
	select X.*, u.Reputation from (
	  select a.OwnerUserId [User Link],
	  sum(case when a.Score = 0 then 0 else 1 end) as [Non Zero Score Answers],
	  sum(case when a.Score = 0 then 1 else 0 end) as [Zero Score Answers]
	from Posts q
	join Posts a on a.Id = q.AcceptedAnswerId
	where a.CommunityOwnedDate is null and a.OwnerUserId is not null
	 and a.OwnerUserId <> isnull(q.OwnerUserId,-1)
	group by a.OwnerUserId
	having sum(case when a.Score = 0 then 1 else 0 end) > 10
	) as X
	join Users u on u.Id = [User Link]
	order by ([Zero Score Answers]+ 0.0) / ([Zero Score Answers]+ [Non Zero Score Answers]+ 0.0) desc
end
GO



create or alter procedure dbo.usp_Q1080 @Useless INT AS
begin

	/*
	Example Execution:
	EXEC dbo.usp_Q1080;
	*/
-- https://data.stackexchange.com/stackoverflow/query/1080/top-users-by-number-of-bounties-won
	-- Top Users by Number of Bounties Won
	SELECT Top 100
	  Posts.OwnerUserId As [User Link], COUNT(*) As BountiesWon
	FROM Votes
	  INNER JOIN Posts ON Votes.PostId = Posts.Id
	WHERE
	  VoteTypeId=9
	GROUP BY
	  Posts.OwnerUserId
	ORDER BY
	  BountiesWon DESC
end
GO



create or alter procedure dbo.usp_Q6134 @months tinyint = 12
as
begin

	/*
	Example Execution:
	EXEC dbo.usp_Q6134 @months = <value>;
	*/
-- https://data.stackexchange.com/stackoverflow/query/6134/total-questions-and-answers-per-month-for-the-last-12
	-- Total Questions and Answers per Month for the last 12
	-- Total number of questions and answers for the last 12 months (in 30 day chunks)

	set nocount on

	create table #ranges (Id int identity, [start] datetime, [finish] datetime)

	insert #ranges
	select top (@months) null, null
	from sysobjects

	declare @oldestPost dateTime

	select @oldestPost = CreationDate from Posts
	where Id = (select max(p2.Id) from Posts p2)

	-- look at 30 day chunks, so stats remain fairly accurate
	-- (month will depend on days per month)

	update #ranges
	  set
	   [start] = DateAdd(d, (0 - Id) * 30, @oldestPost),
	   [finish] = DateAdd(d, (1 - Id) * 30, @oldestPost)



	select start, (select count(*) from Posts where ParentId is null
	   and CreationDate between [start] and [finish] ) as [Total Questions],
		(select count(*) from Posts where ParentId is not null
	   and CreationDate between [start] and [finish] ) as [Total Answers]
	from #ranges
end
GO



create or alter procedure dbo.usp_Q2777 @Useless INT AS
begin

	/*
	Example Execution:
	EXEC dbo.usp_Q2777;
	*/
-- https://data.stackexchange.com/stackoverflow/query/2777/users-by-popular-question-ratio
	-- Users by Popular Question ratio
	-- (only users with at least 10 Popular Questions)

	select top 100
	  Users.Id as [User Link],
	  BadgeCount as [Popular Questions],
	  QuestionCount as [Total Questions],
	  CONVERT(float, BadgeCount)/QuestionCount as [Ratio]
	from Users
	inner join (
	  -- Popular Question badges for each user
	  select
		UserId,
		count(Id) as BadgeCount
	  from Badges
	  where Name = 'Popular Question'
	  group by UserId
	) as Pop on Users.Id = Pop.UserId
	inner join (
	  -- Questions by each user
	  select
		OwnerUserId,
		count(Id) as QuestionCount
	  from posts
	  where PostTypeId = 1
	  group by OwnerUserId
	) as Q on Users.Id = Q.OwnerUserId
	where BadgeCount >= 10
	order by [Ratio] desc;
end
GO



create or alter procedure dbo.usp_Q1933 @Useless INT AS
begin

	/*
	Example Execution:
	EXEC dbo.usp_Q1933;
	*/
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
GO



create or alter procedure dbo.usp_Q1181 @UserId int, @StartDate date, @EndDate date
as
begin

	/*
	Example Execution:
	EXEC dbo.usp_Q1181 @UserId = <value>, @StartDate = <value>, @EndDate = <value>;
	*/
-- https://data.stackexchange.com/stackoverflow/query/1181/vanity-search-links-to-my-website-posted-by-other-people-during-last-2-months
	-- Vanity search: links to my website posted by other people during last 2 months

	WITH    mylink AS
			(
			SELECT  id, REPLACE(WebsiteUrl, 'http://', '') AS site
			FROM    users
			WHERE   id = @UserId
			),
			mylink2 AS
			(
			SELECT  id, CASE SUBSTRING(site, LEN(site), 1) WHEN '/' THEN SUBSTRING(site, 0, LEN(site)) ELSE site END AS se
			FROM    mylink
			)
	SELECT  p.id AS [Post Link], p.LastActivityDate AS [Last Activity]
	FROM    (
			SELECT  p.id
			FROM    mylink2 ml
			JOIN    posts p
			ON      p.body LIKE '%' + se + '%' ESCAPE '!'
					AND p.OwnerUserId <> ml.id
			WHERE   (p.LastActivityDate between @StartDate and @EndDate)
					AND se <> ''
					AND se IS NOT NULL
			UNION
			SELECT  c.PostId
			FROM    mylink2 ml
			JOIN    comments c
			ON      c.text LIKE '%' + se + '%' ESCAPE '!'
					AND c.UserId <> ml.id
			WHERE   (c.CreationDate between @StartDate and @EndDate)
					AND se <> ''
					AND se IS NOT NULL
			) q
	JOIN    posts p
	ON      p.id = q.id
	ORDER BY
			p.LastActivityDate DESC
end
GO



IF OBJECT_ID('dbo.usp_RandomQ') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_RandomQ AS RETURN 0;')
GO

ALTER PROCEDURE dbo.usp_RandomQ WITH RECOMPILE
AS
SET NOCOUNT ON

DECLARE @Id INT = CAST(RAND() * 10000000 AS INT);

IF @Id % 30 = 0 EXEC dbo.usp_Q7521 @Id
ELSE IF @Id % 29 = 0 EXEC dbo.usp_Q36660 @Id
ELSE IF @Id % 28 = 0 EXEC dbo.usp_Q949 @Id
ELSE IF @Id % 27 = 0 EXEC dbo.usp_Q466 @Id
ELSE IF @Id % 26 = 0 EXEC dbo.usp_Q947 @Id
ELSE IF @Id % 25 = 0 EXEC dbo.usp_Q3160 @Id
ELSE IF @Id % 24 = 0 EXEC dbo.usp_Q6627 @Id
ELSE IF @Id % 23 = 0 EXEC dbo.usp_Q6772 @Id
ELSE IF @Id % 22 = 0 EXEC dbo.usp_Q6856 @Id
ELSE IF @Id % 21 = 0 EXEC dbo.usp_Q952 @Id
ELSE IF @Id % 20 = 0 EXEC dbo.usp_Q975 @Id
ELSE IF @Id % 19 = 0 EXEC dbo.usp_Q8116 @Id
ELSE IF @Id % 18 = 0 EXEC dbo.usp_Q4038 @Id
ELSE IF @Id % 17 = 0 EXEC dbo.usp_Q2357 @Id
ELSE IF @Id % 16 = 0 EXEC dbo.usp_Q951 @Id
ELSE IF @Id % 15 = 0 EXEC dbo.usp_Q1433 @Id
ELSE IF @Id % 14 = 0 EXEC dbo.usp_Q7672 @Id
ELSE IF @Id % 13 = 0 EXEC dbo.usp_Q1075286 @Id
ELSE IF @Id % 12 = 0 EXEC dbo.usp_Q1256 @Id
ELSE IF @Id % 11 = 0 EXEC dbo.usp_Q877 @Id
ELSE IF @Id % 10 = 0 EXEC dbo.usp_Q886 @Id
ELSE IF @Id % 9 = 0 EXEC dbo.usp_Q1075285 @Id
ELSE IF @Id % 8 = 0 EXEC dbo.usp_Q10418 'Teacher'
ELSE IF @Id % 7 = 0 EXEC dbo.usp_Q946 @Id
ELSE IF @Id % 6 = 0 EXEC dbo.usp_Q6607 @Id
ELSE IF @Id % 5 = 0 EXEC dbo.usp_Q1080 @Id
ELSE IF @Id % 4 = 0 EXEC dbo.usp_Q6134 12
ELSE IF @Id % 3 = 0 EXEC dbo.usp_Q2777 @Id
ELSE IF @Id % 2 = 0 EXEC dbo.usp_Q1933 @Id
ELSE
    EXEC dbo.usp_Q1181 @Id, '2010-01-01', '2020-01-01'
GO

--EXEC dbo.usp_RandomQ;
