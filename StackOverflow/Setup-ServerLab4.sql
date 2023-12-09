/*
Mastering Server Tuning - Lab 4 Setup

This script is from our Mastering Server Tuning class.
To learn more: https://www.BrentOzar.com/go/tuninglabs

Before running this setup script, restore the Stack Overflow database.
This script runs in 1-5 minutes depending on server hardware - it's changing
indexes as well as creating stored procs and changing server settings.




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
GO
USE StackOverflow;
GO

IF DB_NAME() <> 'StackOverflow'
  RAISERROR(N'Oops! For some reason the StackOverflow database does not exist here.', 20, 1) WITH LOG;
GO

CREATE OR ALTER PROC dbo.usp_ServerLab4_Setup AS
BEGIN
	EXEC sys.sp_configure N'cost threshold', N'5'
	EXEC sys.sp_configure N'max degree of parallelism', N'1'
	/* Set max memory to 85% of the OS's memory: */
	DECLARE @StringToExecute NVARCHAR(400);
	SELECT @StringToExecute = N'EXEC sys.sp_configure N''max server memory (MB)'', N''' + CAST(CAST(physical_memory_kb / 1024 * .85 AS INT) AS NVARCHAR(20)) + N''';'
	  FROM sys.dm_os_sys_info;
	EXEC(@StringToExecute);

	RECONFIGURE WITH OVERRIDE;
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
	IF EXISTS(SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Votes') AND name = '_dta_index_Votes_5_181575685__K3_K2_K5')
		DROP INDEX [_dta_index_Votes_5_181575685__K3_K2_K5] ON dbo.Votes;
	IF EXISTS(SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Votes') AND name = 'IX_PostId_UserId')
		DROP INDEX [IX_PostId_UserId] ON dbo.Votes;
	IF EXISTS(SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Votes') AND name = 'IX_UserId')
		DROP INDEX [IX_UserId] ON dbo.Votes;
	IF EXISTS(SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Users') AND name = 'PK_Users_Id')
		ALTER TABLE [dbo].[Users] DROP CONSTRAINT [PK_Users_Id] WITH ( ONLINE = OFF )
	IF EXISTS(SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Comments') AND name = 'IX_PostId')
		DROP INDEX IX_PostId ON dbo.Comments;
	EXEC DropIndexes @TableName = 'Users';
	ALTER TABLE dbo.Users
	  ALTER COLUMN DisplayName VARCHAR(40);
END
GO

EXEC usp_ServerLab4_Setup;
GO

CREATE OR ALTER   FUNCTION [dbo].[RelatedPosts] ( @PostId INT )
RETURNS @Out TABLE ( PostId BIGINT )
AS
    BEGIN
        INSERT  INTO @Out(PostId)
		SELECT TOP 10 pRelative.Id
		  FROM dbo.PostLinks pl
		  INNER JOIN dbo.Posts pRelative ON pl.RelatedPostId = pRelative.Id
		  WHERE pl.LinkTypeId = 1 AND pRelative.PostTypeId = 1
		  ORDER BY pl.CreationDate DESC;
		 RETURN;
    END;
GO


CREATE OR ALTER VIEW [dbo].[PostsWithRelatives] AS
SELECT p.Id AS OriginalPostId, pRelatives.*
	FROM dbo.Posts p
	CROSS APPLY dbo.RelatedPosts (p.Id) rp
	INNER JOIN dbo.Posts pRelatives ON rp.PostId = pRelatives.Id
GO

CREATE OR ALTER VIEW [dbo].[vwComments] AS 
	SELECT Id, CreationDate, PostId, Score, Text, UserId, IsDeleted, IsPrivate
	FROM dbo.Comments
	WHERE IsDeleted = 0
	  AND IsPrivate = 0; /* No longer showing items marked private as of the 2019 release */
GO

CREATE OR ALTER VIEW [dbo].[vwPosts] AS 
SELECT [Id]
      ,[AcceptedAnswerId]
      ,[AnswerCount]
      ,[Body]
      ,[ClosedDate]
      ,[CommentCount]
      ,[CommunityOwnedDate]
      ,[CreationDate]
      ,[FavoriteCount]
      ,[LastActivityDate]
      ,[LastEditDate]
      ,[LastEditorDisplayName]
      ,[LastEditorUserId]
      ,[OwnerUserId]
      ,[ParentId]
      ,[PostTypeId]
      ,[Score]
      ,[Tags]
      ,[Title]
      ,[ViewCount]
	  ,[IsDeleted]
	  ,[IsPrivate]
  FROM [dbo].[Posts]
	WHERE IsDeleted = 0
	  AND IsPrivate = 0; /* No longer showing items marked private as of the 2019 release */
GO

CREATE OR ALTER VIEW [dbo].[vwUsers] AS 
	SELECT [Id]
		  ,[AboutMe]
		  ,[Age]
		  ,[CreationDate]
		  ,[DisplayName]
		  ,[DownVotes]
		  ,[EmailHash]
		  ,[LastAccessDate]
		  ,[Location]
		  ,[Reputation]
		  ,[UpVotes]
		  ,[Views]
		  ,[WebsiteUrl]
		  ,[AccountId]
		  ,[IsDeleted]
		  ,[IsPrivate]
	FROM dbo.Users
	WHERE IsDeleted = 0
	  AND IsPrivate = 0; /* No longer showing items marked private as of the 2019 release */
GO

CREATE OR ALTER  VIEW [dbo].[vwVotes] AS 
	SELECT Id, PostId, UserId, BountyAmount, VoteTypeId, CreationDate, IsDeleted, IsPrivate
	FROM dbo.Votes
	WHERE IsDeleted = 0
	  AND IsPrivate = 0; /* No longer showing items marked private as of the 2019 release */
GO




CREATE OR ALTER PROC [dbo].[usp_Q36660] AS
BEGIN
/* Source: http://data.stackexchange.com/stackoverflow/query/36660/most-down-voted-questions */

select top 20 count(v.PostId) as 'Vote count', v.PostId AS [Post Link],p.Body
from vwVotes v 
inner join vwPosts p on p.Id=v.PostId
where PostTypeId = 1 and v.VoteTypeId=3
group by v.PostId,p.Body
order by 'Vote count' desc

END
GO



CREATE OR ALTER PROC [dbo].[usp_Q975] AS
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
    vwUsers u1
WHERE
    u1.EmailHash IS NOT NULL
    and (select sum(u3.Reputation) from vwUsers u3 where u3.EmailHash = u1.EmailHash) > 1000  
    and (select count(*) from vwUsers u3 where u3.EmailHash = u1.EmailHash and Reputation > 10) > 1
GROUP BY
    u1.EmailHash
HAVING
    Count(u1.Id) > 1
ORDER BY 
    Accounts DESC

END
GO


CREATE OR ALTER   PROC [dbo].[usp_Report1] @DisplayName NVARCHAR(40)
AS
BEGIN
SELECT *
  FROM dbo.Report_UsersByQuestions
  WHERE DisplayName = @DisplayName;
END;
GO


CREATE OR ALTER   PROC [dbo].[usp_Report2] @LastActivityDate DATETIME, @Tags VARCHAR(150) AS
BEGIN
/* Sample parameters: @LastActivityDate = '2017-07-17 23:16:39.037', @Tags = '%<indexing>%' */
SELECT TOP 100 u.DisplayName, u.Id AS UserId, u.Location, p.Id AS PostId, p.LastActivityDate, p.Body
  FROM dbo.Posts p
    INNER JOIN dbo.Users u ON p.OwnerUserId = u.Id
  WHERE p.Tags LIKE '%<sql-server>%'
    AND p.Tags LIKE @Tags
    AND p.LastActivityDate > @LastActivityDate
  ORDER BY u.DisplayName
END
GO




CREATE OR ALTER   PROC [dbo].[usp_CommentsByUserDisplayName] @DisplayName NVARCHAR(40)
AS
SELECT c.CreationDate, c.Score, c.Text, p.Title, p.PostTypeId
FROM dbo.vwUsers u
INNER JOIN dbo.vwComments c ON u.Id = c.UserId
INNER JOIN dbo.vwPosts p ON c.PostId = p.Id
WHERE u.DisplayName = @DisplayName
ORDER BY c.CreationDate;
GO



CREATE OR ALTER PROC [dbo].[usp_CommentInsert]
	@PostId INT, @UserId INT, @Text NVARCHAR(700) AS
BEGIN
SET NOCOUNT ON
BEGIN TRAN
INSERT INTO dbo.Comments(CreationDate, PostId, Score, Text, UserId)
  VALUES (GETDATE(), @PostId, 0, @Text, @UserId)

/* Give them a reputation point for leaving a comment */
UPDATE dbo.Users 
  SET Reputation = Reputation + 1
  WHERE Id = @UserId;

/* Update the comment count on the post */
UPDATE dbo.Posts
  SET LastActivityDate = GETDATE()
  WHERE Id = @PostId;

/* If the user has added ten comments today on someone else's posts, and they haven't earned Loud Talker yet today, give them a badge */
IF 10 <= (SELECT COUNT(DISTINCT c.Id) 
			FROM dbo.vwComments c
			  INNER JOIN dbo.Posts p ON c.PostId = p.Id AND p.OwnerUserId <> @UserId
			WHERE c.UserId = @UserId AND c.CreationDate >= DATEADD(DD, -24, GETDATE()))
  AND NOT EXISTS(SELECT * FROM dbo.Badges WHERE UserId = @UserId AND Name = 'Loud Talker' AND Date >= DATEADD(DD, -24, GETDATE()))
	BEGIN
	INSERT INTO dbo.Badges(Name, UserId, Date)
	  VALUES ('Loud Talker', @UserId, GETDATE());
	END
COMMIT
END
GO

CREATE OR ALTER PROC [dbo].[usp_PostViewed]
	@PostId INT, @UserId INT AS
BEGIN
SET NOCOUNT ON
BEGIN TRAN

/* If the user hasn't accessed the site in a month, give them a point for coming back.
   This has to be done before we update the user's last access date. */
UPDATE dbo.Users 
  SET Reputation = Reputation + 1
  WHERE Id = @UserId
    AND LastAccessDate <= DATEADD(DD, -30, GETDATE());

UPDATE dbo.Posts
  SET ViewCount = ViewCount + 1
  WHERE Id = @PostId;

UPDATE dbo.Users
  SET Views = Views + 1, LastAccessDate = GETDATE()
  WHERE Id = @UserId;

COMMIT
END
GO



CREATE OR ALTER PROC [dbo].[usp_VoteInsert]
	@PostId INT, @UserId INT, @BountyAmount INT, @VoteTypeId INT AS
BEGIN
SET NOCOUNT ON
BEGIN TRAN


/* Make sure this vote hasn't already been cast */
IF NOT EXISTS(SELECT * FROM dbo.Votes WHERE PostId = @PostId AND UserId = @UserId AND VoteTypeId = @VoteTypeId)
	BEGIN

		/* Make sure the inputs are valid */
		IF NOT EXISTS (SELECT * FROM dbo.VoteTypes WHERE Id = @VoteTypeId)
			BEGIN
				RAISERROR('That VoteTypeId is not valid.', 0, 1) WITH NOWAIT;
				RETURN;
			END

		IF NOT EXISTS (SELECT * FROM dbo.vwPosts WHERE Id = @PostId)
			BEGIN
				RAISERROR('That PostId is not valid.', 0, 1) WITH NOWAIT;
				RETURN;
			END

		IF NOT EXISTS (SELECT * FROM dbo.vwUsers WHERE Id = @UserId)
			BEGIN
				RAISERROR('That UserId is not valid.', 0, 1) WITH NOWAIT;
				RETURN;
			END

		INSERT INTO dbo.Votes (PostId, UserId, BountyAmount, VoteTypeId, CreationDate)
		  VALUES (@PostId, @UserId, @BountyAmount, @VoteTypeId, GETDATE());

		/* UpVotes */
		IF @VoteTypeId = 2
		BEGIN
			UPDATE dbo.Users
			  SET UpVotes = UpVotes + 1
			  WHERE Id = @UserId;
			UPDATE dbo.Posts 
			  SET Score = Score + 1, LastActivityDate = GETDATE()
			  WHERE Id = @PostId;
		END

		/* UpVotes */
		IF @VoteTypeId = 3
		BEGIN
			UPDATE dbo.Users
				SET DownVotes = DownVotes + 1
				WHERE Id = @UserId;
			UPDATE dbo.Posts 
			  SET Score = Score - 1, LastActivityDate = GETDATE()
			  WHERE Id = @PostId;
		END

		/* Favorites */
		IF @VoteTypeId = 5
		BEGIN
			UPDATE dbo.Posts
			  SET FavoriteCount = FavoriteCount + 1, LastActivityDate = GETDATE()
			  WHERE Id = @PostId;
		END

		/* Close */
		IF @VoteTypeId = 6
		BEGIN
			UPDATE dbo.Posts
			  SET ClosedDate = GETDATE(), LastActivityDate = GETDATE()
			  WHERE Id = @PostId;
		END
	END

END
COMMIT

GO








CREATE OR ALTER PROC [dbo].[usp_ServerLab4] WITH RECOMPILE AS
BEGIN
/* Hi! You can ignore this stored procedure.
   This is used to run different random stored procs as part of your class.
   Don't change this in order to "tune" things.
*/
SET NOCOUNT ON

DECLARE @Id1 INT = CAST(RAND() * 10000000 AS INT) + 1;
DECLARE @Id2 INT = CAST(RAND() * 10000000 AS INT) + 1;
DECLARE @Id3 INT = CAST(RAND() * 10000000 AS INT) + 1;

IF @Id1 % 20 = 0
	EXEC dbo.usp_Q36660
ELSE IF @Id1 % 20 = 19
	EXEC dbo.usp_Q975
ELSE IF @Id1 % 20 = 18
	EXEC usp_Report1 @DisplayName = 'Brent Ozar'
ELSE IF @Id1 % 20 = 17
	EXEC usp_Report1 @DisplayName = 'Jon Skeet'
ELSE IF @Id1 % 20 = 16
	EXEC usp_Report2 @LastActivityDate = '2016/01/01', @Tags = '%<indexing>%'
ELSE IF @Id1 % 20 = 15
	EXEC usp_Report2 @LastActivityDate = '2017-07-17 23:16:39.037', @Tags = '%<indexing>%'
ELSE IF @Id1 % 20 = 14
	EXEC [usp_CommentsByUserDisplayName] @DisplayName = 'ZXR'
ELSE IF @Id1 % 20 = 13
	EXEC [usp_CommentsByUserDisplayName] @DisplayName = 'GmA'
ELSE IF @Id1 % 20 = 12
	EXEC [usp_CommentsByUserDisplayName] @DisplayName = 'Fred -ii-'
ELSE IF @Id1 % 20 = 11
	EXEC [usp_CommentsByUserDisplayName] @DisplayName = 'Lightness Races in Orbit'
ELSE IF @Id1 % 20 = 10
	EXEC dbo.usp_CommentInsert @PostId = @Id1, @UserId = @Id2, @Text = 'Nice post!';
ELSE IF @Id1 % 20 = 9
	EXEC dbo.usp_PostViewed @PostId = @Id1, @UserId = @Id2;
ELSE IF @Id1 % 20 = 8
	EXEC dbo.usp_VoteInsert @PostId = @Id1, @UserId = @Id2, @BountyAmount = @Id3, @VoteTypeId = 3;
ELSE IF @Id1 % 20 = 7
	EXEC dbo.usp_CommentInsert @PostId = @Id1, @UserId = @Id2, @Text = 'Nice post!';
ELSE IF @Id1 % 20 = 6
	EXEC dbo.usp_VoteInsert @PostId = @Id1, @UserId = @Id2, @BountyAmount = @Id3, @VoteTypeId = 6;
ELSE IF @Id1 % 20 = 5
	EXEC dbo.usp_VoteInsert @PostId = @Id1, @UserId = @Id2, @BountyAmount = @Id3, @VoteTypeId = 7;
ELSE IF @Id1 % 20 = 4
	EXEC dbo.usp_VoteInsert @PostId = @Id1, @UserId = @Id2, @BountyAmount = @Id3, @VoteTypeId = 2;
ELSE
	EXEC dbo.usp_VoteInsert @PostId = @Id1, @UserId = @Id2, @BountyAmount = @Id3, @VoteTypeId = 5;

WHILE @@TRANCOUNT > 0
	BEGIN
	COMMIT
	END
END
GO