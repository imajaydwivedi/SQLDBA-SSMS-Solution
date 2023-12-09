USE StackOverflow;
GO

create table dbo.PostTags 
(	PostId int not null, 
	TagId int not null,
	constraint pk_PostTags primary key (PostId, Tagid),
	constraint fk_PostTags__PostId foreign key (PostId) references dbo.Posts (Id),
	constraint fk_PostTags__TagId foreign key (TagId) references dbo.Tags (Id)
);
go

alter table dbo.PostTags nocheck constraint fk_PostTags__PostId;
alter table dbo.PostTags nocheck constraint fk_PostTags__TagId;
GO

declare @counter int = 1;
declare @batch_size int = 10000;
while ( ((@counter-1)*@batch_size) <= (select MAX(id) from dbo.Posts) )
begin
	insert dbo.PostTags (PostId, TagId)
	select p.Id as PostId, t.Id as TagId
	from dbo.Posts as p
	outer apply
		( select ltrim(rtrim(pt.value)) as PostTag
		  from STRING_SPLIT(REPLACE(p.Tags,'<',''), '>') as pt
		  where ltrim(rtrim(pt.value)) <> ''
		  and p.Id > ((@counter-1)*@batch_size)
		and p.Id <= (@counter*@batch_size)
		) as pt
	join dbo.Tags as t
		on ltrim(rtrim(t.TagName)) = pt.PostTag
	where p.Id > ((@counter-1)*@batch_size)
		and p.Id <= (@counter*@batch_size)

	set @counter += 1;
end
go

alter table dbo.PostTags with check check constraint fk_PostTags__PostId;
alter table dbo.PostTags with check check constraint fk_PostTags__TagId;
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

create or alter procedure dbo.usp_Bounties_and_Questions_by_Month
as
begin
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

create or alter procedure dbo.usp_get_user_score @UserId int
as
begin
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
	  and a.postTypeId = 2
end
go


create or alter procedure dbo.usp_Jon_Skeet_comparison @UserId int
as 
begin
	-- https://data.stackexchange.com/stackoverflow/query/3160/jon-skeet-comparison
	-- Jon Skeet comparison

	with fights as (
	  select myAnswer.ParentId as Question,
	   myAnswer.Score as MyScore,
	   jonsAnswer.Score as JonsScore
	  from Posts as myAnswer
	  inner join Posts as jonsAnswer
	   on jonsAnswer.OwnerUserId = 22656 and myAnswer.ParentId = jonsAnswer.ParentId
	  where myAnswer.ownerUserId = @UserId and myAnswer.postTypeId = 2
	)

	select
	  case
	   when myScore > JonsScore then 'You win'
	   when myScore < JonsScore then 'Jon wins'
	   else 'Tie'
	  end as 'Winner',
	  Question as [Post Link],
	  myScore as 'My score',
	  jonsScore as "Jon's score"
	from fights;
end
go

CREATE OR ALTER PROCEDURE dbo.usp_get_user_upvotes @UserId int
AS
BEGIN
	-- https://data.stackexchange.com/stackoverflow/query/785/how-many-upvotes-do-i-have-for-each-tag
	-- How many upvotes do I have for each tag?
	-- how long before I get tag badges?

	SELECT --TOP 20 
		TagName,
		COUNT(*) AS UpVotes 
	FROM Tags
		INNER JOIN PostTags ON PostTags.TagId = Tags.id
		INNER JOIN Posts ON Posts.ParentId = PostTags.PostId
		INNER JOIN Votes ON Votes.PostId = Posts.Id and VoteTypeId = 2
	WHERE 
		Posts.OwnerUserId = @UserId
	GROUP BY TagName 
	ORDER BY UpVotes DESC
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



