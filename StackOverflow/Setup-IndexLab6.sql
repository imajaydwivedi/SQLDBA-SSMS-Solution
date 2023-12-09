/*
Mastering Index Tuning - Lab 6
Last updated: 2021-01-25

This script is from our Mastering Index Tuning class.
To learn more: https://www.BrentOzar.com/go/tuninglabs

Before running this setup script, restore the Stack Overflow database.

This script takes about 10 minutes on a machine with 4 cores, 30GB RAM, and SSD storage.



License: Creative Commons Attribution-ShareAlike 3.0 Unported (CC BY-SA 3.0)
More info: https://creativecommons.org/licenses/by-sa/3.0/

You are free to:
* Share - copy and redistribute the material in any medium or format
* Adapt - remix, transform, and build upon the material for any purpose, even 
  commercially

Under the following terms:
* Attribution - You must give appropriate credit, provide a link to the license,
  and indicate if changes were made.
* ShareAlike - If you remix, transform, or build upon the material, you must
  distribute your contributions under the same license as the original.
*/

USE StackOverflow;
GO

IF DB_NAME() <> 'StackOverflow'
  RAISERROR(N'Oops! For some reason the StackOverflow database does not exist here.', 20, 1) WITH LOG;
GO

CREATE OR ALTER     FUNCTION [dbo].[fn_UserHasVoted] ( @UserId INT, @PostId INT )
RETURNS BIT
    WITH RETURNS NULL ON NULL INPUT
AS
    BEGIN
        DECLARE @HasVoted BIT;
		IF EXISTS (SELECT Id
					FROM dbo.Votes
					WHERE UserId = @UserId
					  AND PostId = @PostId)
			SET @HasVoted = 1
		ELSE
			SET @HasVoted = 0;
        RETURN @HasVoted;
    END;
GO

CREATE OR ALTER PROC dbo.usp_BadgeAward @Name NVARCHAR(40), @UserId INT, @Date DATETIME = NULL AS
BEGIN
SET NOCOUNT ON
IF @Date IS NULL SET @Date = GETUTCDATE();
INSERT INTO dbo.Badges(Name, UserId, Date)
VALUES(@Name, @UserId, @Date);
END
GO

CREATE OR ALTER PROC [dbo].[usp_FindInterestingPostsForUser]
	@UserId INT,
	@SinceDate DATETIME AS
BEGIN
SET NOCOUNT ON
SELECT TOP 25 p.*
FROM dbo.Posts p
WHERE PostTypeId = 1 /* Question */
  AND dbo.fn_UserHasVoted(@UserId, p.Id) = 0 /* Only want to show posts they haven't voted on yet */
  AND p.CreationDate >= @SinceDate
ORDER BY p.CreationDate DESC; /* Show the newest stuff first */
END
GO

CREATE OR ALTER   PROC [dbo].[usp_CheckForVoterFraud]
	@UserId INT AS
BEGIN
SET NOCOUNT ON

/* Who has this person voted for? */
DECLARE @Buddies TABLE (UserId INT, VotesCastForThisBuddy INT, VotesReceivedFromThisBuddy INT);
INSERT INTO @Buddies (UserId, VotesCastForThisBuddy)
  SELECT p.OwnerUserId, SUM(1) AS Votes
    FROM dbo.Votes v
	  INNER JOIN dbo.Posts p ON v.PostId = p.Id
	WHERE v.UserId = @UserId
	  AND p.OwnerUserId <> @UserId /* Specifically want other people's posts, where buddies are looking for each others' posts */
	GROUP BY p.OwnerUserId;


/* Have these people voted back in favor of @UserId? */
UPDATE @Buddies
  SET VotesReceivedFromThisBuddy = (SELECT SUM(1)
										FROM dbo.Votes v
										INNER JOIN dbo.Posts p ON v.PostId = p.Id
										WHERE v.UserId = b.UserId
										AND p.OwnerUserId <> @UserId) /* Specifically want other people's posts, where buddies are looking for each others' posts */
  FROM @Buddies b;

SELECT b.*, u.* 
  FROM @Buddies b
  INNER JOIN dbo.Users u ON b.UserId = u.Id
  ORDER BY (b.VotesCastForThisBuddy + b.VotesReceivedFromThisBuddy) DESC;
END
GO

CREATE OR ALTER PROC [dbo].[usp_SearchUsers]
	@DisplayNameLike NVARCHAR(40) = NULL,
	@LocationLike NVARCHAR(100) = NULL,
	@WebsiteUrlLike NVARCHAR(200) = NULL,
	@SortOrder NVARCHAR(20) = NULL AS
BEGIN
SET NOCOUNT ON
IF @SortOrder = 'Location'
	SELECT *
	FROM dbo.Users
	WHERE ((DisplayName LIKE (@DisplayNameLike + N'%') OR @DisplayNameLike IS NULL))
	   AND ((Location LIKE (@LocationLike + N'%') OR @LocationLike IS NULL))
	   AND ((WebsiteUrl LIKE (@WebsiteUrlLike + N'%') OR @WebsiteUrlLike IS NULL))
	   ORDER BY Location, Age;
ELSE IF @SortOrder = 'DownVotes'
	SELECT *
	FROM dbo.Users
	WHERE ((DisplayName LIKE (@DisplayNameLike + N'%') OR @DisplayNameLike IS NULL))
	   AND ((Location LIKE (@LocationLike + N'%') OR @LocationLike IS NULL))
	   AND ((WebsiteUrl LIKE (@WebsiteUrlLike + N'%') OR @WebsiteUrlLike IS NULL))
	   ORDER BY Location, DownVotes;
ELSE IF @SortOrder = 'Age'
	SELECT *
	FROM dbo.Users
	WHERE ((DisplayName LIKE (@DisplayNameLike + N'%') OR @DisplayNameLike IS NULL))
	   AND ((Location LIKE (@LocationLike + N'%') OR @LocationLike IS NULL))
	   AND ((WebsiteUrl LIKE (@WebsiteUrlLike + N'%') OR @WebsiteUrlLike IS NULL))
	   ORDER BY Age, DownVotes;
ELSE
	SELECT *
	FROM dbo.Users
	WHERE ((DisplayName LIKE (@DisplayNameLike + N'%') OR @DisplayNameLike IS NULL))
	   AND ((Location LIKE (@LocationLike + N'%') OR @LocationLike IS NULL))
	   AND ((WebsiteUrl LIKE (@WebsiteUrlLike + N'%') OR @WebsiteUrlLike IS NULL))
	   ORDER BY DownVotes;
END
GO

IF 'Question' <> (SELECT Type FROM dbo.PostTypes WHERE Id = 1)
	BEGIN
	DELETE dbo.PostTypes;
	SET IDENTITY_INSERT dbo.PostTypes ON;
	INSERT INTO dbo.PostTypes (Id, Type) VALUES
		(1, 'Question'),
		(2, 'Answer'),
		(3, 'Wiki'),
		(4, 'TagWikiExerpt'),
		(5, 'TagWiki'),
		(6, 'ModeratorNomination'),
		(7, 'WikiPlaceholder'),
		(8, 'PrivilegeWiki');
	SET IDENTITY_INSERT dbo.PostTypes OFF;
	END
GO

CREATE OR ALTER PROC [dbo].[usp_IndexLab6_Setup] AS
BEGIN

EXEC DropIndexes @TableName = 'Users', @ExceptIndexNames = 'Age,DownVotes,Index_Reputation_Views,Index_DownVotes,For_Reporting,IX_Location,IX_DV_LAD_DN,IX_Popular,IX_ReputationDisplayName';
EXEC DropIndexes @TableName = 'Badges';
EXEC DropIndexes @TableName = 'Comments';
EXEC DropIndexes @TableName = 'PostHistory';
EXEC DropIndexes @TableName = 'PostLinks';
EXEC DropIndexes @TableName = 'Posts';
EXEC DropIndexes @TableName = 'PostTypes';
EXEC DropIndexes @TableName = 'Report_BadgePopularity';
EXEC DropIndexes @TableName = 'Report_UsersByQuestions';
EXEC DropIndexes @TableName = 'Tags';
EXEC DropIndexes @TableName = 'Votes';
EXEC DropIndexes @TableName = 'VoteTypes';


IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'PK_Badges__Id')
	ALTER TABLE [dbo].[Badges] DROP CONSTRAINT [PK_Badges__Id] WITH ( ONLINE = OFF );
ALTER TABLE [dbo].[Badges] ADD  CONSTRAINT [PK_Badges__Id] PRIMARY KEY NONCLUSTERED 
(
	[Id] ASC
)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'Age')
	CREATE INDEX Age ON dbo.Users(Age, DisplayName, LastAccessDate) INCLUDE (Location, EmailHash, AboutMe);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'DownVotes')
	CREATE INDEX DownVotes ON dbo.Users(DownVotes, DisplayName, LastAccessDate) INCLUDE (Location, EmailHash, AboutMe);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'Index_Reputation_Views')
	CREATE INDEX Index_Reputation_Views ON dbo.Users(Reputation, Views) INCLUDE (DisplayName, EmailHash, Location);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'Index_DownVotes')
	CREATE INDEX Index_DownVotes ON dbo.Users(DownVotes) INCLUDE (Location, EmailHash, AboutMe, DisplayName, LastAccessDate);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'For_Reporting')
	CREATE INDEX For_Reporting ON dbo.Users(Id) INCLUDE (AboutMe, DisplayName, Location);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'IX_Location')
	CREATE INDEX IX_Location ON dbo.Users(Location, DisplayName, LastAccessDate, EmailHash) INCLUDE (AboutMe);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'IX_DV_LAD_DN')
	CREATE INDEX IX_DV_LAD_DN ON dbo.Users(DownVotes, DisplayName, LastAccessDate);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'IX_Popular')
	CREATE INDEX IX_Popular ON dbo.Users(DisplayName) WHERE Reputation > 100;
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Users]') AND name = N'IX_Reputation_DisplayName')
	CREATE INDEX IX_Reputation_DisplayName ON dbo.Users(Reputation, DisplayName);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Badges]') AND name = N'IX_UserId')
	CREATE INDEX IX_UserId ON dbo.Badges(UserId);

IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Comments' AND COLUMN_NAME = 'IsDeleted')
	ALTER TABLE dbo.Comments
		ADD IsDeleted BIT NOT NULL DEFAULT 0;
IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Comments' AND COLUMN_NAME = 'IsPrivate')
	ALTER TABLE dbo.Comments
		ADD IsPrivate BIT NOT NULL DEFAULT 0;
IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Posts' AND COLUMN_NAME = 'IsDeleted')
	ALTER TABLE dbo.Posts
		ADD IsDeleted BIT NOT NULL DEFAULT 0;
IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Posts' AND COLUMN_NAME = 'IsPrivate')
	ALTER TABLE dbo.Posts
		ADD IsPrivate BIT NOT NULL DEFAULT 0;
IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'IsDeleted')
	ALTER TABLE dbo.Users
		ADD IsDeleted BIT NOT NULL DEFAULT 0;
IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'IsPrivate')
	ALTER TABLE dbo.Users
		ADD IsPrivate BIT NOT NULL DEFAULT 0;
IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Votes' AND COLUMN_NAME = 'IsDeleted')
	ALTER TABLE dbo.Votes
		ADD IsDeleted BIT NOT NULL DEFAULT 0;
IF NOT EXISTS(SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Votes' AND COLUMN_NAME = 'IsPrivate')
	ALTER TABLE dbo.Votes
		ADD IsPrivate BIT NOT NULL DEFAULT 0;

EXEC('CREATE OR ALTER VIEW dbo.vwComments AS SELECT * FROM dbo.Comments WHERE IsDeleted = 0 AND IsPrivate = 0;');
EXEC('CREATE OR ALTER VIEW dbo.vwPosts AS SELECT * FROM dbo.Posts WHERE IsDeleted = 0 AND IsPrivate = 0;');
EXEC('CREATE OR ALTER VIEW dbo.vwUsers AS SELECT * FROM dbo.Users WHERE IsDeleted = 0 AND IsPrivate = 0;');
EXEC('CREATE OR ALTER VIEW dbo.vwVotes AS SELECT * FROM dbo.Votes WHERE IsDeleted = 0 AND IsPrivate = 0;');


UPDATE dbo.Badges 
  SET Name = CASE WHEN Name = 'Nice Answer' THEN 'Really, Really, Really Very Nice Answer'
				  WHEN Name = 'Popular Question' THEN 'Really, Really, Really Popular Question'
				  WHEN Name = 'Scholar' THEN 'Very, Very, Very, Very Smart Scholar'
			END
  WHERE Name IN('Nice Answer', 'Popular Question', 'Scholar')
  AND Id % 2 = 0;
EXEC('	CREATE OR ALTER TRIGGER Badges_Insert ON dbo.Badges
		AFTER INSERT  
		AS  
		BEGIN
		SET NOCOUNT ON
		BEGIN TRAN
		/* Update their bio to show that they earned the badge */
			UPDATE dbo.Users
				SET Reputation = Reputation + 10, 
					AboutMe = N''I just earned a badge! I earned: '' + COALESCE(i.Name, ''Unknown'')
							+ ''. It is an elite club - I am one of: '' + COALESCE(CAST((SELECT SUM(1) FROM dbo.Badges bOthers WHERE bOthers.Name = i.Name) AS NVARCHAR(20)), '' Unknown'')
			FROM inserted i
			  INNER JOIN dbo.Users u ON u.Id = i.UserId;

			/* Mark any of their reports as needing a refresh: */
			DELETE dbo.Report_BadgePopularity
				FROM inserted i
				INNER JOIN dbo.Report_BadgePopularity b ON i.Name = b.BadgeName
				WHERE b.TotalAwarded > 0;

			DELETE dbo.Report_UsersByQuestions
				FROM inserted i
				INNER JOIN dbo.Report_UsersByQuestions b ON i.UserId = b.UserId AND b.CreationDate > ''2017/01/01'';

		COMMIT

		END;  ');
END
GO  


EXEC usp_IndexLab6_Setup;
GO


CREATE OR ALTER PROC dbo.usp_Q1718 @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/1718/up-vs-down-votes-by-day-of-week-of-question-or-answer */
SELECT
    CASE WHEN PostTypeId = 1 THEN 'Question' ELSE 'Answer' END As [Post Type],
    DATENAME(WEEKDAY, p.CreationDate) AS Day,
    Count(*) AS Amount,
    SUM(CASE WHEN VoteTypeId = 2 THEN 1 ELSE 0 END) AS UpVotes,
    SUM(CASE WHEN VoteTypeId = 3 THEN 1 ELSE 0 END) AS DownVotes,
    CASE WHEN SUM(CASE WHEN VoteTypeId = 3 THEN 1 ELSE 0 END) = 0 THEN NULL
     ELSE (CAST(SUM(CASE WHEN VoteTypeId = 2 THEN 1 ELSE 0 END) AS float) / CAST(SUM(CASE WHEN VoteTypeId = 3 THEN 1 ELSE 0 END) AS float))
    END AS UpVoteDownVoteRatio
FROM
    vwVotes v JOIN vwPosts p ON v.PostId=p.Id
WHERE
    PostTypeId In (1,2)
 AND
    VoteTypeId In (2,3)
  AND 
    UserId = @UserId
GROUP BY
    PostTypeId, DATEPART(WEEKDAY, p.CreationDate), DATENAME(WEEKDAY, p.CreationDate)
ORDER BY
    PostTypeId, DATEPART(WEEKDAY, p.CreationDate)
END
GO

CREATE OR ALTER PROC dbo.usp_Q2777 @NotUsed INT = NULL AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/2777/users-by-popular-question-ratio */
select top 100
  vwUsers.Id as [User Link],
  BadgeCount as [Popular Questions],
  QuestionCount as [Total Questions],
  CONVERT(float, BadgeCount)/QuestionCount as [Ratio]
from vwUsers
inner join (
  -- Popular Question badges for each user
  select
    UserId,
    count(Id) as BadgeCount
  from Badges
  where Name = 'Popular Question'
  group by UserId
) as Pop on vwUsers.Id = Pop.UserId
inner join (
  -- Questions by each user
  select
    OwnerUserId,
    count(Id) as QuestionCount
  from vwPosts
  where PostTypeId = 1
  group by OwnerUserId
) as Q on vwUsers.Id = Q.OwnerUserId
where BadgeCount >= 10
order by [Ratio] desc;
END
GO

CREATE OR ALTER PROC usp_Q181756 @Score INT = 1, @Gold INT = 50, @Silver INT = 10, @Bronze INT = 1 AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/181756/question-asking-badges */
with user_questions as (
  select OwnerUserId, count(*) number_asked, avg(Score) avg_score
  from vwPosts
  where PostTypeId = 1
        and Score >= @Score
        and OwnerUserId is not null
  group by OwnerUserId
),

asking_badges as (
  select case 
           when number_asked >= @Gold
           then 1
         end gold,
         case
           when number_asked >= @Silver
           then 1
         end silver,
         case
           when number_asked >= @Bronze  then 1
         end bronze,
         case
           when number_asked is null  then 1
         end none
  from user_questions
       right join Users on OwnerUserId = Id
)

select count(*) users, 
       sum(gold) gold, 
       sum(silver) silver, 
       sum(bronze) bronze, 
       sum(none) none
from asking_badges;
END
GO

CREATE OR ALTER PROC usp_Q69607 @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/69607/what-is-my-archaeologist-badge-progress */
SELECT COUNT(*) FROM vwPosts p
INNER JOIN vwPosts a on a.ParentId = p.Id
WHERE p.LastEditDate < DATEADD(month, -6, p.LastActivityDate)
AND( p.OwnerUserId = @UserId OR  a.OwnerUserId = @UserId);
END
GO



CREATE OR ALTER PROC usp_Q8553 @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/8553/how-many-edits-do-i-have */
WITH qaedits AS (
  SELECT
  (
    SELECT COUNT(*) FROM vwPosts
    WHERE PostTypeId = 1
    AND LastEditorUserId = vwUsers.Id
  ) AS QuestionEdits,
  (
    SELECT COUNT(*) FROM vwPosts
    WHERE PostTypeId = 2
    AND LastEditorUserId = vwUsers.Id
  ) AS AnswerEdits
  FROM vwUsers
  WHERE Id = @UserId
),

edits AS (
  SELECT QuestionEdits, AnswerEdits, QuestionEdits + AnswerEdits AS TotalEdits
  FROM qaedits
)

SELECT QuestionEdits, AnswerEdits, TotalEdits,
  CASE WHEN TotalEdits >= 1 THEN 'Received' ELSE '0%' END AS EditorBadge,
  CASE WHEN TotalEdits >= 100
    THEN 'Received'
    ELSE Cast(TotalEdits AS varchar) + '%'
  END AS StrunkAndWhiteBadge,
  CASE WHEN TotalEdits >= 600
    THEN 'Received'
    ELSE Cast(TotalEdits / 6 AS varchar) + '%'
  END AS CopyEditorBadge
FROM edits
END
GO



CREATE OR ALTER PROC dbo.usp_Q10098 @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/10098/how-long-until-i-get-the-pundit-badge */
SELECT TOP 20 
    vwPosts.Title, vwComments.Text, vwComments.Score, vwPosts.Id, vwPosts.ParentId
FROM vwComments
     INNER JOIN vwPosts ON vwComments.PostId = vwPosts.Id
WHERE 
    UserId = @UserId
ORDER BY Score DESC;
END
GO

CREATE OR ALTER   PROC [dbo].[usp_AcceptedAnswersByUser]
	@UserId INT AS
BEGIN
SET NOCOUNT ON
SELECT pQ.Title, pQ.Id, pA.Title, pA.Body, c.CreationDate, u.DisplayName, c.Text
FROM dbo.vwPosts pA
  INNER JOIN dbo.vwPosts pQ ON pA.ParentId = pQ.Id
			AND pA.Id = pQ.AcceptedAnswerId
  LEFT OUTER JOIN dbo.vwComments c ON pA.Id = c.PostId
			AND c.UserId <> @UserId
  LEFT OUTER JOIN dbo.Users u ON c.UserId = u.Id
WHERE pA.OwnerUserId = @UserId
ORDER BY pQ.CreationDate, c.CreationDate
END
GO


CREATE OR ALTER PROC dbo.usp_Q17321 @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/17321/my-activity-by-utc-hour */
-- My Activity by UTC Hour
-- What time of day do I post questions and answers most?
SELECT
 datepart(hour,CreationDate) AS hour,
 count(CASE WHEN PostTypeId = 1 THEN 1 END) AS questions,
 count(CASE WHEN PostTypeId = 2 THEN 1 END) AS answers
FROM vwPosts
WHERE
  PostTypeId IN (1,2) AND
  OwnerUserId=@UserId
GROUP BY datepart(hour,CreationDate)
ORDER BY hour;
END
GO


CREATE OR ALTER PROC dbo.usp_Q25355 @MyId INT = 26837, @TheirId INT = 22656 AS
BEGIN
/* SOURCE http://data.stackexchange.com/stackoverflow/query/25355/have-we-met */
declare @LikeMyName nvarchar(40)
select @LikeMyName = '%' + DisplayName + '%' from Users where Id = @MyId

declare @TheirName nvarchar(40)
declare @LikeTheirName nvarchar(40)
select @TheirName = DisplayName from Users where Id = @TheirId
select @LikeTheirName = '%' + @TheirName + '%'

-- Question/Answer meetings
  select
   Questions.Id as [Post Link],  
    case
      when Questions.OwnerUserId = @TheirId then @TheirName + '''s question, my answer'
    else 'My question, ' + @TheirName + '''s answer'
    end as [What]
  from vwPosts as Questions
  inner join vwPosts as Answers
   on Questions.Id = Answers.ParentId
  where Answers.PostTypeId = 2 and Questions.PostTypeId = 1
   and ((Questions.OwnerUserId = @TheirId and Answers.OwnerUserId = @MyId )
     or (Questions.OwnerUserId = @MyId and Answers.OwnerUserId = @TheirId ))
union
  -- Comments on owned posts
  select p.Id as [Post Link],
    case
      when p.PostTypeId = 1 and p.OwnerUserId = @TheirId then @TheirName + '''s question, my comment'
      when p.PostTypeId = 1 and p.OwnerUserId = @MyId then 'My question, ' + @TheirName + '''s comment'
      when p.PostTypeId = 2 and p.OwnerUserId = @TheirId then @TheirName + '''s answer, my comment'
      when p.PostTypeId = 2 and p.OwnerUserId = @MyId then 'My answer, ' + @TheirName + '''s comment'
    end as [What]  
  from vwPosts p
  inner join vwComments c
    on p.Id = c.PostId
  where ((p.OwnerUserId = @TheirId and c.UserId = @MyId )
     or (p.OwnerUserId = @MyId and c.UserId = @TheirId ))

union
 -- @comments on posts
  select p.Id as [Post Link],
    case
      when UserId = @TheirId then @TheirName + '''s reply to my comment'
      when UserId = @MyId then 'My reply to ' + @TheirName + '''s comment'
    end as [What]  
  from vwComments c
    inner join vwPosts p on c.PostId = p.Id
  where ((UserId = @TheirId and Text like @LikeMyName )
     or (UserId = @MyId and Text like @LikeTheirName))

order by [Post Link];
END
GO


CREATE OR ALTER PROC dbo.usp_Q74873 @UserId INT AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/74873/how-much-reputation-are-you-getting-from-your-past-work */
-- How much reputation are you getting from your past work?
-- Take the "unexpected" reputation coming from your answers from last month.
-- Suppose now you constantly get those, and figure out how much rep per day
-- you are getting for your past work
SELECT @UserId AS [User Link], @UserId AS Id, Reputation, AgeInDays AS AccountAgeInDays,CAST(CAST(RepFromPast AS float)/AgeInDays AS int) AS OldReputationPerDay
  FROM 
      (
      SELECT @UserId AS Id, SUM(Reputation) AS RepFromPast 
        FROM (
            SELECT CASE WHEN VoteTypeId = 2 THEN 10 ELSE -2 END AS Reputation    
              FROM
                vwVotes v JOIN vwPosts p ON v.PostId=p.Id JOIN Posts parents ON p.ParentId=parents.Id
              WHERE p.PostTypeId = 2
                AND p.OwnerUserId = @UserId
                AND v.VoteTypeId In (2,3)
                AND datediff(day, p.CreationDate,v.CreationDate) > 30
                AND p.OwnerUserId != parents.OwnerUserId
          ) AS RepCounts
        ) As RepAndUserCount
      JOIN 
        (
        SELECT Id, Reputation, CONVERT(int, GETDATE() - CreationDate) as AgeInDays
          FROM vwUsers
          WHERE vwUsers.Id = @UserId
        ) AS AccountAge
      ON RepAndUserCount.Id=AccountAge.Id;
END
GO

CREATE OR ALTER PROC dbo.usp_Q9900 @UserId INT = 26837 AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/9900/distribution-of-scores-on-my-answers */
-- Distribution of scores on my answers
-- Shows how often a user's answers get a specific score. Related to http://odata.stackexchange.com/stackoverflow/q/1930

DECLARE @totalAnswers DECIMAL;
SELECT @totalAnswers = COUNT(*) FROM Posts WHERE PostTypeId = 2 AND OwnerUserId = @UserId;

SELECT Score AS AnswerScore, Occurences,
  CASE WHEN Frequency < 1 THEN '<1%' ELSE Cast(Cast(ROUND(Frequency, 0) AS INT) AS VARCHAR) + '%' END AS Frequency
FROM (
  SELECT Score, COUNT(*) AS Occurences, (COUNT(*) / @totalAnswers) * 100 AS Frequency
  FROM vwPosts
  WHERE PostTypeId = 2                 -- answers
    AND OwnerUserId = 26837       -- by you
  GROUP BY Score
) AS answers
ORDER BY answers.Frequency DESC, Score;
END
GO

CREATE OR ALTER PROC usp_Q49864 @UserId INT = 26837 AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/49864/my-comments-ordered-by-score-pundit-badge-progress  */
SELECT 
    c.Score,
    c.Id as [Comment Link],
    -- PostId as [Post Link],
    /*CASE 
    WHEN Q.Id is not NULL THEN CONCAT("<a href=\"http://stackoverflow.com/a/", Posts.Id, "\">", Q.Title, "</a>")
          ELSE CONCAT("<a href=\"http://stackoverflow.com/q/", Posts.Id, "\">", Posts.Title, "</a>") 
    END as QTitle,*/
    -- PostId,
    -- Posts.ParentId,
    c.CreationDate
FROM 
    vwComments c /*join Posts on Comments.PostId = Posts.Id
        left join Posts as Q on Posts.ParentId = Q.Id*/
WHERE 
    UserId = @UserId and c.Score > 0
ORDER BY 
    c.Score DESC;
END
GO



CREATE OR ALTER PROC dbo.usp_Q283566 @Keyword NVARCHAR(30) = '%graph%' AS
BEGIN
-- leading/trailing space helps match stackoverflow.com search behavior

-- Build the filter result set; contains key and unanswered 'skew' value
CREATE TABLE #unanswered (Id int primary key, Age int, UnansweredSkew int)
INSERT #unanswered
SELECT q.Id as Id, 
CAST((GETDATE() - q.CreationDate) AS INT) as Age,
CASE WHEN q.AcceptedAnswerId is null THEN -10 
     WHEN q.AcceptedAnswerId is not null THEN 0 END AS [Total]
FROM vwPosts q
WHERE ((q.Tags LIKE '%adal%')
    OR (q.Tags LIKE '%office365%')
    OR (q.Tags LIKE '%azure-active-directory%'))
AND ((LOWER(q.Body) LIKE @Keyword)
   OR(LOWER(q.Title) LIKE @Keyword))

    
-- Build the weighting result set, using the one above as driver
SELECT p.Id AS [Post Link], 
p.ViewCount, 
p.AnswerCount, 
CONVERT(VARCHAR(10), p.CreationDate, 1) as Created,
u.Age,
CASE WHEN p.AcceptedAnswerId is null THEN 'false' ELSE 'true' END AS Answered,
((p.ViewCount * .05) + (u.Age * .1) + p.AnswerCount + u.UnansweredSkew) AS Weight
FROM vwPosts p
JOIN #unanswered u ON u.Id = p.Id
ORDER BY Answered ASC, Weight DESC;
END
GO


CREATE OR ALTER PROC dbo.usp_Q66093 @UserId INT = 22656 AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/66093/posts-by-jon-skeet-per-day-versus-total-badges-hes-earnt */

select CAST(p.CreationDate as Date) as PostDate, count(p.Id) as Posts,
(
select count(b.Id) / 100
  from Badges b
  where b.UserId = u.Id
  and b.Date <= CAST(p.CreationDate as Date)
  ) as BadgesEarned
from vwPosts p, vwUsers u
  where u.Id = @UserId
  and p.OwnerUserId = u.Id
  group by CAST(p.CreationDate as Date), u.Id
order by CAST(p.CreationDate as Date);
END
GO



CREATE OR ALTER PROC dbo.usp_Q40304 AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/40304/colorado-c-people */
select *
from vwUsers
where 1=1
  --AND displayName like 'L%'
  AND UPPER(Location) LIKE 'BOULDER, CO'
  AND AboutMe LIKE '%C#%'
ORDER BY Reputation DESC;
END
GO

CREATE OR ALTER PROC dbo.usp_Q43336 AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/43336/who-brings-in-the-crowds */

-- Who Brings in the Crowds?
-- Users sorted by total number of views of their questions per day (softened by 30 days to keep new hot posts from skewing the results)

-- I tried removing the softener, but the results are really more useful with it
-- updated to use last database access (by a logged in user -- best we've got) instead of current_timestamp

SELECT TOP 50
  q.OwnerUserId as [User Link],
  count(q.Id) as Questions,
  sum(q.ViewCount/(30+datediff(day, q.CreationDate, datadumptime ))) AS [Question Views per Day]
FROM vwPosts AS q, (select max(LastAccessDate) as datadumptime from vwUsers) tmp
WHERE  
  q.CommunityOwnedDate is null AND
  q.OwnerUserId is NOT null AND
  q.PostTypeId=1
GROUP BY q.OwnerUserId
ORDER BY [Question Views per Day] DESC;
END
GO






CREATE OR ALTER PROC [dbo].[usp_IndexLab6] WITH RECOMPILE AS
BEGIN
/* Hi! You can ignore this stored procedure.
   This is used to run different random stored procs as part of your class.
   Don't change this in order to "tune" things.
*/
SET NOCOUNT ON

DECLARE @Id1 INT = CAST(RAND() * 10000000 AS INT) + 1;
DECLARE @Id2 INT = CAST(RAND() * 10000000 AS INT) + 1;
DECLARE @Id3 INT = CAST(RAND() * 10000000 AS INT) + 1;

IF @Id1 % 30 = 24
	EXEC dbo.usp_Q1718 @UserId = @Id1;
ELSE IF @Id1 % 30 = 23
	EXEC dbo.usp_Q2777;
ELSE IF @Id1 % 30 = 22
	EXEC dbo.usp_Q181756 @Score = @Id1, @Gold = @Id2, @Silver = @Id3;
ELSE IF @Id1 % 30 = 21
	EXEC dbo.usp_Q69607 @UserId = @Id1;
ELSE IF @Id1 % 30 = 20
	EXEC dbo.usp_Q8553 @UserId = @Id1;
ELSE IF @Id1 % 30 = 19
	EXEC dbo.usp_Q10098 @UserId = @Id1;
ELSE IF @Id1 % 30 = 18
	EXEC dbo.usp_Q17321 @UserId = @Id1;
ELSE IF @Id1 % 30 = 17
	EXEC dbo.usp_Q25355 @MyId = @Id1, @TheirId = @Id2;
ELSE IF @Id1 % 30 = 16
	EXEC dbo.usp_Q74873 @UserId = @Id1;
ELSE IF @Id1 % 30 = 15
	EXEC dbo.usp_Q9900 @UserId = @Id1;
ELSE IF @Id1 % 30 = 14
	EXEC dbo.usp_Q49864 @UserId = @Id1;
ELSE IF @Id1 % 30 = 13
	EXEC dbo.usp_Q283566;
ELSE IF @Id1 % 30 = 12
	EXEC dbo.usp_Q66093 @UserId = @Id1;
ELSE IF @Id1 % 30 = 10
	EXEC dbo.usp_SearchUsers @DisplayNameLike = 'Brent', @LocationLike = NULL, @WebsiteUrlLike = 'Google', @SortOrder = 'Age';
ELSE IF @Id1 % 30 = 9
	EXEC dbo.usp_SearchUsers @DisplayNameLike = NULL, @LocationLike = 'Chicago', @WebsiteUrlLike = NULL, @SortOrder = 'Location';
ELSE IF @Id1 % 30 = 8
	EXEC dbo.usp_SearchUsers @DisplayNameLike = NULL, @LocationLike = NULL, @WebsiteUrlLike = 'BrentOzar.com', @SortOrder = 'Reputation';
ELSE IF @Id1 % 30 = 7
	EXEC dbo.usp_SearchUsers @DisplayNameLike = 'Brent', @LocationLike = 'Chicago', @WebsiteUrlLike = 'BrentOzar.com', @SortOrder = 'DownVotes';
ELSE IF @Id1 % 30 = 6
	EXEC dbo.usp_FindInterestingPostsForUser @UserId = @Id1, @SinceDate = '2017/06/10';
ELSE IF @Id1 % 30 = 5
	EXEC dbo.usp_CheckForVoterFraud @UserId = @Id1;
ELSE IF @Id1 % 30 = 4
	EXEC dbo.usp_AcceptedAnswersByUser @UserId = @Id1;
ELSE IF @Id1 % 30 = 3
	EXEC dbo.usp_AcceptedAnswersByUser @UserId = @Id1;
ELSE IF @Id1 % 30 = 2
	EXEC dbo.usp_BadgeAward @Name = 'Loud Talker', @UserId = 26837;
ELSE IF @Id1 % 30 = 1
	EXEC dbo.usp_Q43336;
ELSE
	EXEC dbo.usp_Q40304;

WHILE @@TRANCOUNT > 0
	BEGIN
	COMMIT
	END
END
GO