/*
Mastering Server Tuning - Lab 2 Setup

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

CREATE OR ALTER PROC dbo.usp_ServerLab2_Setup AS
BEGIN
	EXEC sys.sp_configure N'max degree of parallelism', N'1';

	RECONFIGURE WITH OVERRIDE;
	EXEC DropIndexes @TableName = 'Users';
	IF EXISTS(SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Users') AND name = 'PK_Users_Id')
		ALTER TABLE [dbo].[Users] DROP CONSTRAINT [PK_Users_Id] WITH ( ONLINE = OFF );
	ALTER TABLE dbo.Users
	  ALTER COLUMN Location VARCHAR(100);
END
GO

EXEC usp_ServerLab2_Setup;
GO

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'BannedTags')
BEGIN
	CREATE TABLE dbo.BannedTags (Id INT IDENTITY(1,1) PRIMARY KEY CLUSTERED, Tag VARCHAR(150), IsDeleted BIT, Reason VARCHAR(100));
	INSERT INTO dbo.BannedTags(Tag, IsDeleted, Reason)
	  VALUES ('<executesqlserveragentjob>', 0, 'Too obscure'),
			 ('<sails-mssqlserver>', 0, 'Too obscure'),
			 ('<odbc-sql-server-driver>', 0, 'Too obscure'),
			 ('<sql-server-2000>', 0, 'No longer supported'),
			 ('<sql-server-2005>', 0, 'No longer supported'),
			 ('<sql-server-7>', 0, 'No longer supported');
	INSERT INTO dbo.BannedTags(Tag, IsDeleted, Reason)
	  SELECT DISTINCT Tags, 0, 'Too good at sailboat racing.'
		FROM dbo.Posts
		WHERE Tags LIKE '%oracle%'
	CREATE INDEX IX_Tag ON dbo.BannedTags(Tag);
END
GO


CREATE OR ALTER FUNCTION dbo.IsTagBanned ( @PostId INT )
RETURNS TINYINT
    WITH RETURNS NULL ON NULL INPUT
AS
    BEGIN
		/* Check to see if a post's tag has been banned */
        DECLARE @Banned TINYINT = 0;
		IF EXISTS (SELECT 1 FROM dbo.Posts p INNER JOIN dbo.BannedTags bt ON p.Tags = bt.Tag WHERE p.Id = @PostId)
			SET @Banned = 1;
        RETURN @Banned;
    END;
GO

CREATE OR ALTER PROC dbo.usp_GetNewPostsForUser @DisplayName NVARCHAR(40) AS
BEGIN
/* Get the last date a user logged in */
DECLARE @LastLoginDate VARCHAR(50);
SELECT @LastLoginDate = LastAccessDate
  FROM dbo.Users
  WHERE DisplayName = @DisplayName
	AND LastAccessDate IS NOT NULL;

/* Show the first 100 questions entered after they last logged in */
SELECT TOP 100 *
  FROM dbo.Posts p
  WHERE p.CreationDate > @LastLoginDate
    AND dbo.IsTagBanned(p.Id) = 0
	AND p.PostTypeId = 1  /* Only questions */
  ORDER BY p.CreationDate;  
END
GO

CREATE OR ALTER PROC dbo.usp_GetUsersByDisplayName @DisplayName sql_variant AS
BEGIN
SELECT *
  FROM dbo.Users
  WHERE DisplayName = @DisplayName;
END
GO

CREATE OR ALTER PROC dbo.usp_GetUsersByLocation 
	@Location NVARCHAR(100) = N'%Iceland%' AS
BEGIN
SELECT *
  FROM dbo.Users
  WHERE Location LIKE @Location
  ORDER BY DisplayName;
END
GO




CREATE OR ALTER PROC [dbo].[usp_ServerLab2] WITH RECOMPILE AS
BEGIN
/* Hi! You can ignore this stored procedure.
   This is used to run different random stored procs as part of your class.
   Don't change this in order to "tune" things.
*/
SET NOCOUNT ON

DECLARE @Id1 INT = CAST(RAND() * 10000000 AS INT) + 1;

IF @Id1 % 8 = 0
	EXEC dbo.usp_GetUsersByLocation @Location = N'United States';
ELSE IF @Id1 % 8 = 7
	EXEC dbo.usp_GetUsersByLocation @Location = N'Germany%';
ELSE IF @Id1 % 8 = 6
	EXEC dbo.usp_GetUsersByLocation @Location = N'India%';
ELSE IF @Id1 % 8 = 5
	EXEC dbo.usp_GetUsersByDisplayName @DisplayName = N'Brent Ozar';
ELSE IF @Id1 % 8 = 4
	EXEC dbo.usp_GetUsersByDisplayName @DisplayName = N'Lady Gaga';
ELSE IF @Id1 % 8 = 3
    EXEC usp_GetNewPostsForUser 'Jeff Atwood';
ELSE IF @Id1 % 8 = 2
    EXEC usp_GetNewPostsForUser 'Jon Skeet';
ELSE
    EXEC usp_GetNewPostsForUser 'Brent Ozar';

WHILE @@TRANCOUNT > 0
	BEGIN
	COMMIT
	END
END
GO