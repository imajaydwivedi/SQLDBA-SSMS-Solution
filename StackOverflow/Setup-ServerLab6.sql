/*
Mastering Server Tuning - Lab 6 Setup

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
EXEC sys.sp_configure N'cost threshold', N'50'
GO
EXEC sys.sp_configure N'max degree of parallelism', N'4'
GO
/* Set max memory to 85% of the OS's memory: */
DECLARE @StringToExecute NVARCHAR(400);
SELECT @StringToExecute = N'EXEC sys.sp_configure N''max server memory (MB)'', N''' + CAST(CAST(physical_memory_kb / 1024 * .85 AS INT) AS NVARCHAR(20)) + N''';'
	FROM sys.dm_os_sys_info;
EXEC(@StringToExecute);
GO 
RECONFIGURE WITH OVERRIDE
GO
USE StackOverflow;
GO
IF DB_NAME() <> 'StackOverflow'
  RAISERROR(N'Oops! For some reason the StackOverflow database does not exist here.', 20, 1) WITH LOG;
GO


ALTER TABLE dbo.Badges
  ADD IsDeleted BIT NOT NULL DEFAULT 0, IsPrivate BIT NOT NULL DEFAULT 0;
ALTER TABLE dbo.Comments
  ADD IsDeleted BIT NOT NULL DEFAULT 0, IsPrivate BIT NOT NULL DEFAULT 0;
ALTER TABLE dbo.Posts
  ADD IsDeleted BIT NOT NULL DEFAULT 0, IsPrivate BIT NOT NULL DEFAULT 0;
ALTER TABLE dbo.Users
  ADD IsDeleted BIT NOT NULL DEFAULT 0, IsPrivate BIT NOT NULL DEFAULT 0;
ALTER TABLE dbo.Votes
  ADD IsDeleted BIT NOT NULL DEFAULT 0, IsPrivate BIT NOT NULL DEFAULT 0;
GO

CREATE OR ALTER VIEW dbo.vwBadges AS
SELECT *
FROM dbo.Badges
WHERE IsDeleted = 0
AND IsPrivate = 0;
GO

CREATE OR ALTER VIEW dbo.vwComments AS
SELECT *
FROM dbo.Comments
WHERE IsDeleted = 0
AND IsPrivate = 0;
GO

CREATE OR ALTER VIEW dbo.vwPosts AS
SELECT *
FROM dbo.Posts
WHERE IsDeleted = 0
AND IsPrivate = 0;
GO

CREATE OR ALTER VIEW dbo.vwUsers AS
SELECT *
FROM dbo.Users
WHERE IsDeleted = 0
AND IsPrivate = 0;
GO

CREATE OR ALTER VIEW dbo.vwVotes AS
SELECT *
FROM dbo.Votes
WHERE IsDeleted = 0
AND IsPrivate = 0;
GO

/* 
We need to audit changes to all our tables. I did some quick Googling, and this
solution on Stack Overflow looks legit. What could go wrong?
https://stackoverflow.com/questions/19737723/log-record-changes-in-sql-server-in-an-audit-table
*/

IF NOT EXISTS
      (SELECT * FROM sysobjects WHERE id = OBJECT_ID(N'[dbo].[Audit]') 
               AND OBJECTPROPERTY(id, N'IsUserTable') = 1)
       CREATE TABLE Audit 
               (Type CHAR(1), 
               TableName VARCHAR(128), 
               PK VARCHAR(1000), 
               FieldName VARCHAR(128), 
               OldValue VARCHAR(1000), 
               NewValue VARCHAR(1000), 
               UpdateDate datetime, 
               UserName VARCHAR(128))
GO

CREATE OR ALTER TRIGGER TR_Badges_AUDIT ON Badges FOR UPDATE
AS

DECLARE @bit INT ,
       @field INT ,
       @maxfield INT ,
       @char INT ,
       @fieldname VARCHAR(128) ,
       @TableName VARCHAR(128) ,
       @PKCols VARCHAR(1000) ,
       @sql VARCHAR(2000), 
       @UpdateDate VARCHAR(21) ,
       @UserName VARCHAR(128) ,
       @Type CHAR(1) ,
       @PKSelect VARCHAR(1000)


--You will need to change @TableName to match the table to be audited. 
-- Here we made GUESTS for your example.
SELECT @TableName = 'Badges'

-- date and user
SELECT         @UserName = SYSTEM_USER ,
       @UpdateDate = CONVERT (NVARCHAR(30),GETDATE(),126)

-- Action
IF EXISTS (SELECT * FROM inserted)
       IF EXISTS (SELECT * FROM deleted)
               SELECT @Type = 'U'
       ELSE
               SELECT @Type = 'I'
ELSE
       SELECT @Type = 'D'

-- get list of columns
SELECT * INTO #ins FROM inserted
SELECT * INTO #del FROM deleted

-- Get primary key columns for full outer join
SELECT @PKCols = COALESCE(@PKCols + ' and', ' on') 
               + ' i.' + c.COLUMN_NAME + ' = d.' + c.COLUMN_NAME
       FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,

              INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
       WHERE   pk.TABLE_NAME = @TableName
       AND     CONSTRAINT_TYPE = 'PRIMARY KEY'
       AND     c.TABLE_NAME = pk.TABLE_NAME
       AND     c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME

-- Get primary key select for insert
SELECT @PKSelect = COALESCE(@PKSelect+'+','') 
       + '''<' + COLUMN_NAME 
       + '=''+convert(varchar(100),
coalesce(i.' + COLUMN_NAME +',d.' + COLUMN_NAME + '))+''>''' 
       FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,
               INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
       WHERE   pk.TABLE_NAME = @TableName
       AND     CONSTRAINT_TYPE = 'PRIMARY KEY'
       AND     c.TABLE_NAME = pk.TABLE_NAME
       AND     c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME

IF @PKCols IS NULL
BEGIN
       RAISERROR('no PK on table %s', 16, -1, @TableName)
       RETURN
END

SELECT         @field = 0, 
       @maxfield = MAX(ORDINAL_POSITION) 
       FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName
WHILE @field < @maxfield
BEGIN
       SELECT @field = MIN(ORDINAL_POSITION) 
               FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_NAME = @TableName 
               AND ORDINAL_POSITION > @field
       SELECT @bit = (@field - 1 )% 8 + 1
       SELECT @bit = POWER(2,@bit - 1)
       SELECT @char = ((@field - 1) / 8) + 1
       IF SUBSTRING(COLUMNS_UPDATED(),@char, 1) & @bit > 0
                                       OR @Type IN ('I','D')
       BEGIN
               SELECT @fieldname = COLUMN_NAME 
                       FROM INFORMATION_SCHEMA.COLUMNS 
                       WHERE TABLE_NAME = @TableName 
                       AND ORDINAL_POSITION = @field
               SELECT @sql = '
insert Audit (    Type, 
               TableName, 
               PK, 
               FieldName, 
               OldValue, 
               NewValue, 
               UpdateDate, 
               UserName)
select ''' + @Type + ''',''' 
       + @TableName + ''',' + @PKSelect
       + ',''' + @fieldname + ''''
       + ',convert(varchar(1000),d.' + @fieldname + ')'
       + ',convert(varchar(1000),i.' + @fieldname + ')'
       + ',''' + @UpdateDate + ''''
       + ',''' + @UserName + ''''
       + ' from #ins i full outer join #del d'
       + @PKCols
       + ' where i.' + @fieldname + ' <> d.' + @fieldname 
       + ' or (i.' + @fieldname + ' is null and  d.'
                                + @fieldname
                                + ' is not null)' 
       + ' or (i.' + @fieldname + ' is not null and  d.' 
                                + @fieldname
                                + ' is null)' 
               EXEC (@sql)
       END
END

GO



CREATE OR ALTER TRIGGER TR_Comments_AUDIT ON Comments FOR UPDATE
AS

DECLARE @bit INT ,
       @field INT ,
       @maxfield INT ,
       @char INT ,
       @fieldname VARCHAR(128) ,
       @TableName VARCHAR(128) ,
       @PKCols VARCHAR(1000) ,
       @sql VARCHAR(2000), 
       @UpdateDate VARCHAR(21) ,
       @UserName VARCHAR(128) ,
       @Type CHAR(1) ,
       @PKSelect VARCHAR(1000)


--You will need to change @TableName to match the table to be audited. 
-- Here we made GUESTS for your example.
SELECT @TableName = 'Comments'

-- date and user
SELECT         @UserName = SYSTEM_USER ,
       @UpdateDate = CONVERT (NVARCHAR(30),GETDATE(),126)

-- Action
IF EXISTS (SELECT * FROM inserted)
       IF EXISTS (SELECT * FROM deleted)
               SELECT @Type = 'U'
       ELSE
               SELECT @Type = 'I'
ELSE
       SELECT @Type = 'D'

-- get list of columns
SELECT * INTO #ins FROM inserted
SELECT * INTO #del FROM deleted

-- Get primary key columns for full outer join
SELECT @PKCols = COALESCE(@PKCols + ' and', ' on') 
               + ' i.' + c.COLUMN_NAME + ' = d.' + c.COLUMN_NAME
       FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,

              INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
       WHERE   pk.TABLE_NAME = @TableName
       AND     CONSTRAINT_TYPE = 'PRIMARY KEY'
       AND     c.TABLE_NAME = pk.TABLE_NAME
       AND     c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME

-- Get primary key select for insert
SELECT @PKSelect = COALESCE(@PKSelect+'+','') 
       + '''<' + COLUMN_NAME 
       + '=''+convert(varchar(100),
coalesce(i.' + COLUMN_NAME +',d.' + COLUMN_NAME + '))+''>''' 
       FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,
               INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
       WHERE   pk.TABLE_NAME = @TableName
       AND     CONSTRAINT_TYPE = 'PRIMARY KEY'
       AND     c.TABLE_NAME = pk.TABLE_NAME
       AND     c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME

IF @PKCols IS NULL
BEGIN
       RAISERROR('no PK on table %s', 16, -1, @TableName)
       RETURN
END

SELECT         @field = 0, 
       @maxfield = MAX(ORDINAL_POSITION) 
       FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName
WHILE @field < @maxfield
BEGIN
       SELECT @field = MIN(ORDINAL_POSITION) 
               FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_NAME = @TableName 
               AND ORDINAL_POSITION > @field
       SELECT @bit = (@field - 1 )% 8 + 1
       SELECT @bit = POWER(2,@bit - 1)
       SELECT @char = ((@field - 1) / 8) + 1
       IF SUBSTRING(COLUMNS_UPDATED(),@char, 1) & @bit > 0
                                       OR @Type IN ('I','D')
       BEGIN
               SELECT @fieldname = COLUMN_NAME 
                       FROM INFORMATION_SCHEMA.COLUMNS 
                       WHERE TABLE_NAME = @TableName 
                       AND ORDINAL_POSITION = @field
               SELECT @sql = '
insert Audit (    Type, 
               TableName, 
               PK, 
               FieldName, 
               OldValue, 
               NewValue, 
               UpdateDate, 
               UserName)
select ''' + @Type + ''',''' 
       + @TableName + ''',' + @PKSelect
       + ',''' + @fieldname + ''''
       + ',convert(varchar(1000),d.' + @fieldname + ')'
       + ',convert(varchar(1000),i.' + @fieldname + ')'
       + ',''' + @UpdateDate + ''''
       + ',''' + @UserName + ''''
       + ' from #ins i full outer join #del d'
       + @PKCols
       + ' where i.' + @fieldname + ' <> d.' + @fieldname 
       + ' or (i.' + @fieldname + ' is null and  d.'
                                + @fieldname
                                + ' is not null)' 
       + ' or (i.' + @fieldname + ' is not null and  d.' 
                                + @fieldname
                                + ' is null)' 
               EXEC (@sql)
       END
END

GO



CREATE OR ALTER TRIGGER TR_Posts_AUDIT ON Posts FOR UPDATE
AS

DECLARE @bit INT ,
       @field INT ,
       @maxfield INT ,
       @char INT ,
       @fieldname VARCHAR(128) ,
       @TableName VARCHAR(128) ,
       @PKCols VARCHAR(1000) ,
       @sql VARCHAR(2000), 
       @UpdateDate VARCHAR(21) ,
       @UserName VARCHAR(128) ,
       @Type CHAR(1) ,
       @PKSelect VARCHAR(1000)


--You will need to change @TableName to match the table to be audited. 
-- Here we made GUESTS for your example.
SELECT @TableName = 'Posts'

-- date and user
SELECT         @UserName = SYSTEM_USER ,
       @UpdateDate = CONVERT (NVARCHAR(30),GETDATE(),126)

-- Action
IF EXISTS (SELECT * FROM inserted)
       IF EXISTS (SELECT * FROM deleted)
               SELECT @Type = 'U'
       ELSE
               SELECT @Type = 'I'
ELSE
       SELECT @Type = 'D'

-- get list of columns
SELECT * INTO #ins FROM inserted
SELECT * INTO #del FROM deleted

-- Get primary key columns for full outer join
SELECT @PKCols = COALESCE(@PKCols + ' and', ' on') 
               + ' i.' + c.COLUMN_NAME + ' = d.' + c.COLUMN_NAME
       FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,

              INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
       WHERE   pk.TABLE_NAME = @TableName
       AND     CONSTRAINT_TYPE = 'PRIMARY KEY'
       AND     c.TABLE_NAME = pk.TABLE_NAME
       AND     c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME

-- Get primary key select for insert
SELECT @PKSelect = COALESCE(@PKSelect+'+','') 
       + '''<' + COLUMN_NAME 
       + '=''+convert(varchar(100),
coalesce(i.' + COLUMN_NAME +',d.' + COLUMN_NAME + '))+''>''' 
       FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,
               INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
       WHERE   pk.TABLE_NAME = @TableName
       AND     CONSTRAINT_TYPE = 'PRIMARY KEY'
       AND     c.TABLE_NAME = pk.TABLE_NAME
       AND     c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME

IF @PKCols IS NULL
BEGIN
       RAISERROR('no PK on table %s', 16, -1, @TableName)
       RETURN
END

SELECT         @field = 0, 
       @maxfield = MAX(ORDINAL_POSITION) 
       FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName
WHILE @field < @maxfield
BEGIN
       SELECT @field = MIN(ORDINAL_POSITION) 
               FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_NAME = @TableName 
               AND ORDINAL_POSITION > @field
       SELECT @bit = (@field - 1 )% 8 + 1
       SELECT @bit = POWER(2,@bit - 1)
       SELECT @char = ((@field - 1) / 8) + 1
       IF SUBSTRING(COLUMNS_UPDATED(),@char, 1) & @bit > 0
                                       OR @Type IN ('I','D')
       BEGIN
               SELECT @fieldname = COLUMN_NAME 
                       FROM INFORMATION_SCHEMA.COLUMNS 
                       WHERE TABLE_NAME = @TableName 
                       AND ORDINAL_POSITION = @field
               SELECT @sql = '
insert Audit (    Type, 
               TableName, 
               PK, 
               FieldName, 
               OldValue, 
               NewValue, 
               UpdateDate, 
               UserName)
select ''' + @Type + ''',''' 
       + @TableName + ''',' + @PKSelect
       + ',''' + @fieldname + ''''
       + ',convert(varchar(1000),d.' + @fieldname + ')'
       + ',convert(varchar(1000),i.' + @fieldname + ')'
       + ',''' + @UpdateDate + ''''
       + ',''' + @UserName + ''''
       + ' from #ins i full outer join #del d'
       + @PKCols
       + ' where i.' + @fieldname + ' <> d.' + @fieldname 
       + ' or (i.' + @fieldname + ' is null and  d.'
                                + @fieldname
                                + ' is not null)' 
       + ' or (i.' + @fieldname + ' is not null and  d.' 
                                + @fieldname
                                + ' is null)' 
               EXEC (@sql)
       END
END

GO



CREATE OR ALTER TRIGGER TR_Users_AUDIT ON Users FOR UPDATE
AS

DECLARE @bit INT ,
       @field INT ,
       @maxfield INT ,
       @char INT ,
       @fieldname VARCHAR(128) ,
       @TableName VARCHAR(128) ,
       @PKCols VARCHAR(1000) ,
       @sql VARCHAR(2000), 
       @UpdateDate VARCHAR(21) ,
       @UserName VARCHAR(128) ,
       @Type CHAR(1) ,
       @PKSelect VARCHAR(1000)


--You will need to change @TableName to match the table to be audited. 
-- Here we made GUESTS for your example.
SELECT @TableName = 'Users'

-- date and user
SELECT         @UserName = SYSTEM_USER ,
       @UpdateDate = CONVERT (NVARCHAR(30),GETDATE(),126)

-- Action
IF EXISTS (SELECT * FROM inserted)
       IF EXISTS (SELECT * FROM deleted)
               SELECT @Type = 'U'
       ELSE
               SELECT @Type = 'I'
ELSE
       SELECT @Type = 'D'

-- get list of columns
SELECT * INTO #ins FROM inserted
SELECT * INTO #del FROM deleted

-- Get primary key columns for full outer join
SELECT @PKCols = COALESCE(@PKCols + ' and', ' on') 
               + ' i.' + c.COLUMN_NAME + ' = d.' + c.COLUMN_NAME
       FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,

              INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
       WHERE   pk.TABLE_NAME = @TableName
       AND     CONSTRAINT_TYPE = 'PRIMARY KEY'
       AND     c.TABLE_NAME = pk.TABLE_NAME
       AND     c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME

-- Get primary key select for insert
SELECT @PKSelect = COALESCE(@PKSelect+'+','') 
       + '''<' + COLUMN_NAME 
       + '=''+convert(varchar(100),
coalesce(i.' + COLUMN_NAME +',d.' + COLUMN_NAME + '))+''>''' 
       FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,
               INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
       WHERE   pk.TABLE_NAME = @TableName
       AND     CONSTRAINT_TYPE = 'PRIMARY KEY'
       AND     c.TABLE_NAME = pk.TABLE_NAME
       AND     c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME

IF @PKCols IS NULL
BEGIN
       RAISERROR('no PK on table %s', 16, -1, @TableName)
       RETURN
END

SELECT         @field = 0, 
       @maxfield = MAX(ORDINAL_POSITION) 
       FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName
WHILE @field < @maxfield
BEGIN
       SELECT @field = MIN(ORDINAL_POSITION) 
               FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_NAME = @TableName 
               AND ORDINAL_POSITION > @field
       SELECT @bit = (@field - 1 )% 8 + 1
       SELECT @bit = POWER(2,@bit - 1)
       SELECT @char = ((@field - 1) / 8) + 1
       IF SUBSTRING(COLUMNS_UPDATED(),@char, 1) & @bit > 0
                                       OR @Type IN ('I','D')
       BEGIN
               SELECT @fieldname = COLUMN_NAME 
                       FROM INFORMATION_SCHEMA.COLUMNS 
                       WHERE TABLE_NAME = @TableName 
                       AND ORDINAL_POSITION = @field
               SELECT @sql = '
insert Audit (    Type, 
               TableName, 
               PK, 
               FieldName, 
               OldValue, 
               NewValue, 
               UpdateDate, 
               UserName)
select ''' + @Type + ''',''' 
       + @TableName + ''',' + @PKSelect
       + ',''' + @fieldname + ''''
       + ',convert(varchar(1000),d.' + @fieldname + ')'
       + ',convert(varchar(1000),i.' + @fieldname + ')'
       + ',''' + @UpdateDate + ''''
       + ',''' + @UserName + ''''
       + ' from #ins i full outer join #del d'
       + @PKCols
       + ' where i.' + @fieldname + ' <> d.' + @fieldname 
       + ' or (i.' + @fieldname + ' is null and  d.'
                                + @fieldname
                                + ' is not null)' 
       + ' or (i.' + @fieldname + ' is not null and  d.' 
                                + @fieldname
                                + ' is null)' 
               EXEC (@sql)
       END
END

GO

CREATE OR ALTER TRIGGER TR_Votes_AUDIT ON Votes FOR UPDATE
AS

DECLARE @bit INT ,
       @field INT ,
       @maxfield INT ,
       @char INT ,
       @fieldname VARCHAR(128) ,
       @TableName VARCHAR(128) ,
       @PKCols VARCHAR(1000) ,
       @sql VARCHAR(2000), 
       @UpdateDate VARCHAR(21) ,
       @UserName VARCHAR(128) ,
       @Type CHAR(1) ,
       @PKSelect VARCHAR(1000)


--You will need to change @TableName to match the table to be audited. 
-- Here we made GUESTS for your example.
SELECT @TableName = 'Votes'

-- date and user
SELECT         @UserName = SYSTEM_USER ,
       @UpdateDate = CONVERT (NVARCHAR(30),GETDATE(),126)

-- Action
IF EXISTS (SELECT * FROM inserted)
       IF EXISTS (SELECT * FROM deleted)
               SELECT @Type = 'U'
       ELSE
               SELECT @Type = 'I'
ELSE
       SELECT @Type = 'D'

-- get list of columns
SELECT * INTO #ins FROM inserted
SELECT * INTO #del FROM deleted

-- Get primary key columns for full outer join
SELECT @PKCols = COALESCE(@PKCols + ' and', ' on') 
               + ' i.' + c.COLUMN_NAME + ' = d.' + c.COLUMN_NAME
       FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,

              INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
       WHERE   pk.TABLE_NAME = @TableName
       AND     CONSTRAINT_TYPE = 'PRIMARY KEY'
       AND     c.TABLE_NAME = pk.TABLE_NAME
       AND     c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME

-- Get primary key select for insert
SELECT @PKSelect = COALESCE(@PKSelect+'+','') 
       + '''<' + COLUMN_NAME 
       + '=''+convert(varchar(100),
coalesce(i.' + COLUMN_NAME +',d.' + COLUMN_NAME + '))+''>''' 
       FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,
               INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
       WHERE   pk.TABLE_NAME = @TableName
       AND     CONSTRAINT_TYPE = 'PRIMARY KEY'
       AND     c.TABLE_NAME = pk.TABLE_NAME
       AND     c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME

IF @PKCols IS NULL
BEGIN
       RAISERROR('no PK on table %s', 16, -1, @TableName)
       RETURN
END

SELECT         @field = 0, 
       @maxfield = MAX(ORDINAL_POSITION) 
       FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName
WHILE @field < @maxfield
BEGIN
       SELECT @field = MIN(ORDINAL_POSITION) 
               FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_NAME = @TableName 
               AND ORDINAL_POSITION > @field
       SELECT @bit = (@field - 1 )% 8 + 1
       SELECT @bit = POWER(2,@bit - 1)
       SELECT @char = ((@field - 1) / 8) + 1
       IF SUBSTRING(COLUMNS_UPDATED(),@char, 1) & @bit > 0
                                       OR @Type IN ('I','D')
       BEGIN
               SELECT @fieldname = COLUMN_NAME 
                       FROM INFORMATION_SCHEMA.COLUMNS 
                       WHERE TABLE_NAME = @TableName 
                       AND ORDINAL_POSITION = @field
               SELECT @sql = '
insert Audit (    Type, 
               TableName, 
               PK, 
               FieldName, 
               OldValue, 
               NewValue, 
               UpdateDate, 
               UserName)
select ''' + @Type + ''',''' 
       + @TableName + ''',' + @PKSelect
       + ',''' + @fieldname + ''''
       + ',convert(varchar(1000),d.' + @fieldname + ')'
       + ',convert(varchar(1000),i.' + @fieldname + ')'
       + ',''' + @UpdateDate + ''''
       + ',''' + @UserName + ''''
       + ' from #ins i full outer join #del d'
       + @PKCols
       + ' where i.' + @fieldname + ' <> d.' + @fieldname 
       + ' or (i.' + @fieldname + ' is null and  d.'
                                + @fieldname
                                + ' is not null)' 
       + ' or (i.' + @fieldname + ' is not null and  d.' 
                                + @fieldname
                                + ' is null)' 
               EXEC (@sql)
       END
END

GO



CREATE OR ALTER PROC dbo.usp_UserLogin @UserId INT AS
BEGIN
UPDATE dbo.Users
  SET LastAccessDate = GETUTCDATE()
  WHERE Id = @UserId;
END
GO

CREATE OR ALTER PROC dbo.usp_UserUpdateProfile 
	@UserId INT,
	@AboutMe NVARCHAR(MAX),
	@Age INT,
	@DisplayName NVARCHAR(40),
	@Location NVARCHAR(100),
	@WebsiteUrl NVARCHAR(200) AS
BEGIN
UPDATE dbo.Users
  SET LastAccessDate = GETUTCDATE(),
	AboutMe = COALESCE(@AboutMe, AboutMe),
	Age = COALESCE(@Age, Age),
	DisplayName = COALESCE(@DisplayName, DisplayName),
	Location = COALESCE(@Location, Location),
	WebsiteUrl = COALESCE(@WebsiteUrl, WebsiteUrl)
  WHERE Id = @UserId;
END
GO

CREATE OR ALTER PROC dbo.usp_VoteUpPost @PostId INT, @UserId INT AS
BEGIN
	BEGIN TRAN
	UPDATE dbo.Posts 
		SET Score = Score + 1
		WHERE Id = @PostId;
	UPDATE dbo.Users
		SET UpVotes = UpVotes + 1,
		    LastAccessDate = GETUTCDATE()
		FROM dbo.Users u
		  LEFT OUTER JOIN dbo.vwPosts p ON u.Id = p.OwnerUserId /* Not allowed to upvote your own post */
		WHERE u.Id = @UserId;
	COMMIT
END
GO

CREATE OR ALTER PROC dbo.usp_VoteDownPost @PostId INT, @UserId INT AS
BEGIN
	BEGIN TRAN
	UPDATE dbo.Users
		SET DownVotes = DownVotes + 1,
		    LastAccessDate = GETUTCDATE()
		WHERE Id = @UserId;
	UPDATE dbo.Posts 
		SET Score = Score - 1
		FROM dbo.Posts p
		  LEFT OUTER JOIN dbo.vwUsers u ON u.Id = p.OwnerUserId /* Not allowed to downvote your own post */
		WHERE p.Id = @PostId;
	COMMIT
END
GO

CREATE OR ALTER PROC dbo.usp_PostViewed @PostId INT, @UserId INT AS
BEGIN
	DECLARE @DisplayName NVARCHAR(40);
	BEGIN TRAN

	SELECT @DisplayName = DisplayName
		FROM dbo.Users
		WHERE Id = @UserId;

	UPDATE dbo.Posts
		SET ViewCount = ViewCount + 1,
		    LastActivityDate = GETUTCDATE(),
			LastEditorUserId = @UserId,
			LastEditorDisplayName = @DisplayName
		WHERE Id = @PostId;

	UPDATE dbo.Users
		SET LastAccessDate = GETUTCDATE()
		WHERE Id = @UserId;
	COMMIT
END
GO


CREATE OR ALTER PROC dbo.usp_VoteUpComment @CommentId INT, @UserId INT AS
BEGIN
	BEGIN TRAN
	UPDATE dbo.Comments 
		SET Score = Score + 1
		WHERE Id = @CommentId;
	UPDATE dbo.Users
		SET UpVotes = UpVotes + 1,
		    LastAccessDate = GETUTCDATE()
		FROM dbo.Users u
		  LEFT OUTER JOIN dbo.vwComments c ON u.Id = c.UserId /* Not allowed to upvote your own comment */
		WHERE u.Id = @UserId;
	COMMIT
END
GO

CREATE OR ALTER PROC dbo.usp_VoteDownComment @CommentId INT, @UserId INT AS
BEGIN
	BEGIN TRAN
	UPDATE dbo.Users
		SET DownVotes = DownVotes + 1,
		    LastAccessDate = GETUTCDATE()
		WHERE Id = @UserId;
	UPDATE dbo.Comments 
		SET Score = Score - 1
		FROM dbo.Comments c
		  LEFT OUTER JOIN dbo.vwUsers u ON u.Id = c.UserId /* Not allowed to downvote your own comment */
		WHERE c.Id = @CommentId;
	COMMIT
END
GO

CREATE OR ALTER PROC dbo.usp_BadgeDelete @BadgeId INT, @UserId INT AS
BEGIN
	BEGIN TRAN
	/* Make sure it's not their own badge */
	IF EXISTS (SELECT * FROM dbo.Badges WHERE Id = @BadgeId AND UserId = @UserId)
		RETURN;
	UPDATE dbo.Badges SET IsDeleted = 1
		WHERE Id = @BadgeId;
	INSERT INTO dbo.Badges (Name, UserId, Date, IsDeleted, IsPrivate)
	  VALUES ('Badge Deleter', @UserId, GETUTCDATE(), 0, 0);
	COMMIT
END
GO

CREATE OR ALTER PROC dbo.usp_CommentDelete @CommentId INT, @UserId INT AS
BEGIN
	BEGIN TRAN
	/* Make sure it's not their own comment */
	IF EXISTS (SELECT * FROM dbo.Comments WHERE Id = @CommentId AND UserId = @UserId)
		RETURN;
	UPDATE dbo.Comments SET IsDeleted = 1
		WHERE Id = @CommentId;
	INSERT INTO dbo.Badges (Name, UserId, Date, IsDeleted, IsPrivate)
	  VALUES ('Comment Deleter', @UserId, GETUTCDATE(), 0, 0);
	COMMIT
END
GO

CREATE OR ALTER PROC dbo.usp_PostsDelete @PostId INT, @UserId INT AS
BEGIN
	BEGIN TRAN
	/* Make sure it's not their own post */
	IF EXISTS (SELECT * FROM dbo.Posts WHERE Id = @PostId AND (OwnerUserId = @UserId OR LastEditorUserId = @UserId))
		RETURN;
	UPDATE dbo.Posts SET IsDeleted = 1
		WHERE Id = @PostId;
	INSERT INTO dbo.Badges (Name, UserId, Date, IsDeleted, IsPrivate)
	  VALUES ('Post Deleter', @UserId, GETUTCDATE(), 0, 0);
	COMMIT
END
GO


CREATE OR ALTER PROC dbo.usp_UsersDelete @UserId INT, @DeletedByUserId INT AS
BEGIN
	BEGIN TRAN
	/* Make sure it's not their own user account */
	IF @UserId = @DeletedByUserId
		RETURN;
	UPDATE dbo.Users SET IsDeleted = 1
		WHERE Id = @UserId;
	INSERT INTO dbo.Badges (Name, UserId, Date, IsDeleted, IsPrivate)
	  VALUES ('User Deleter', @DeletedByUserId, GETUTCDATE(), 0, 0);
	COMMIT
END
GO


CREATE OR ALTER PROC dbo.usp_VotesDelete @VoteId INT, @UserId INT AS
BEGIN
	BEGIN TRAN
	/* Make sure it's not their own post */
	IF EXISTS (SELECT * FROM dbo.Votes WHERE Id = @VoteId AND UserId = @UserId)
		RETURN;
	UPDATE dbo.Votes SET IsDeleted = 1
		WHERE Id = @VoteId;
	INSERT INTO dbo.Badges (Name, UserId, Date, IsDeleted, IsPrivate)
	  VALUES ('Vote Deleter', @UserId, GETUTCDATE(), 0, 0);
	COMMIT
END
GO


CREATE OR ALTER PROC dbo.usp_AuditReport @TableName NVARCHAR(128) = NULL, @FieldName NVARCHAR(128) = NULL, 
	@StartDate DATE, @EndDate DATE, @PageNumber INT = 1, @PageSize INT = 100 AS
BEGIN
SELECT *
  FROM dbo.Audit
  WHERE (TableName = @TableName OR @TableName IS NULL)
    AND (FieldName = @FieldName OR @FieldName IS NULL)
	AND (UpdateDate >= @StartDate OR @StartDate IS NULL)
	AND (UpdateDate <= @EndDate OR @EndDate IS NULL)
  ORDER BY UpdateDate, FieldName
  OFFSET ((@PageNumber - 1) * @PageSize) ROWS
  FETCH NEXT @PageSize ROWS ONLY;
END
GO

CREATE TABLE [dbo].[DBA](
	[Type] [char](1) NULL,
	[TableName] [varchar](128) NULL,
	[PK] [varchar](1000) NULL,
	[FieldName] [varchar](128) NULL,
	[OldValue] [varchar](1000) NULL,
	[NewValue] [varchar](1000) NULL,
	[UpdateDate] [datetime] NULL,
	[UserName] [varchar](128) NULL
)
GO

CREATE INDEX IX_TableName ON dbo.DBA (TableName, FieldName);
CREATE INDEX IX_FieldName ON dbo.DBA (FieldName, TableName);
CREATE INDEX IX_UpdateDate ON dbo.DBA (UpdateDate, TableName, FieldName);
CREATE INDEX IX_UserName ON dbo.DBA (UserName, FieldName, TableName, UpdateDate);
GO

USE [msdb]
GO
DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'Archive the Audit Table', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
select @jobId
GO
EXEC msdb.dbo.sp_add_jobserver @job_name=N'Archive the Audit Table';
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'Archive the Audit Table', @step_name=N'Archive the audit table', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Move records from the Audit table into the archives
   I hate using serializable, but I have to make sure we
   get every single audit record, or the security team
   will kill me. */
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
BEGIN TRAN
INSERT INTO dbo.DBA (Type, TableName, PK, FieldName, OldValue, NewValue, UpdateDate, UserName)
  SELECT Type, TableName, PK, FieldName, OldValue, NewValue, UpdateDate, UserName
  FROM dbo.Audit;
DELETE dbo.Audit WITH (TABLOCK);
COMMIT TRAN
', 
		@database_name=N'StackOverflow', 
		@flags=0
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_name=N'Archive the Audit Table', 
		@enabled=1, 
		@start_step_id=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'', 
		@notify_page_operator_name=N''
GO
USE [msdb]
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'Archive the Audit Table', @name=N'Every Minute', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20180216, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO


USE StackOverflow;
GO



CREATE OR ALTER PROC [dbo].[usp_ServerLab5] WITH RECOMPILE AS
BEGIN
/* Hi! You can ignore this stored procedure.
   This is used to run different random stored procs as part of your class.
   Don't change this in order to "tune" things.
*/
SET NOCOUNT ON
 
DECLARE @Id1 INT = CAST(RAND() * 10000000 AS INT) + 1;
DECLARE @Id2 INT = CAST(RAND() * 10000000 AS INT) + 1;
DECLARE @Id3 INT = CAST(RAND() * 10000000 AS INT) + 1;
 
 
IF @Id2 % 2 = 0
    BEGIN
	/* 2/3 of the workload is reports against the audit table*/
	IF @Id1 % 2 = 0
		EXEC usp_AuditReport @TableName = 'Badges', @StartDate = '2018/01/01', @EndDate = '2018/12/31';
	ELSE 
		EXEC usp_AuditReport @TableName = 'Comments', @FieldName = 'Text',  @StartDate = '2018/01/01', @EndDate = '2018/12/31';
    END
ELSE IF @Id1 % 13 = 12
    EXEC usp_VotesDelete @Id1, @Id2
ELSE IF @Id1 % 13 = 11
    EXEC usp_UsersDelete @Id1, @Id2
ELSE IF @Id1 % 13 = 10
    EXEC usp_PostsDelete @Id1, @Id2
ELSE IF @Id1 % 13 = 9
    EXEC usp_CommentDelete @Id1, @Id2
ELSE IF @Id1 % 13 = 8
    EXEC usp_BadgeDelete @Id1, @Id2
ELSE IF @Id1 % 13 = 7
    EXEC usp_VoteDownComment @Id1, @Id2
ELSE IF @Id1 % 13 = 6
    EXEC usp_VoteUpComment @Id1, @Id2
ELSE IF @Id1 % 13 = 5
    EXEC usp_PostViewed @Id1, @Id2
ELSE IF @Id1 % 13 = 4
    EXEC usp_VoteDownPost @Id1, @Id2
ELSE IF @Id1 % 13 = 3
    EXEC usp_VoteUpPost @Id1, @Id2
ELSE IF @Id1 % 13 = 2
	EXEC usp_UserUpdateProfile @UserId = @Id1, @Age = 21, @DisplayName = 'John Malkovich', @Location = 'Mertin-Flemmer Building, New York, NY', @WebsiteUrl = 'https://www.youtube.com/watch?v=Q6Fuxkinhug', @AboutMe = 'He''s very well respected. That jewel thief movie, for example. The point is that this is a very odd thing, supernatural, for lack of a better word. It raises all sorts of philosophical questions about the nature of self, about the existence of the soul. Am I me? Is Malkovich Malkovich? Was the Buddha right, is duality an illusion? Do you realize what a metaphysical can of worms this portal is? I don''t think I can go on living my life as I have lived it.'
ELSE
    EXEC usp_UserLogin @UserId = @Id1
 
WHILE @@TRANCOUNT > 0
	BEGIN
	COMMIT
	END
END
GO

UPDATE dbo.Badges SET Name = 'Malkovich', UserId = UserId + 1, Date = GETDATE(), IsDeleted = 1, IsPrivate = 1
	WHERE Id % 1000 = 1;
GO
UPDATE dbo.Comments SET CreationDate = GETDATE(), PostId = PostId + 1, Score = Score + 1, Text = 'Malkovich', UserId = UserId + 1, IsDeleted = 1, IsPrivate = 1
	WHERE Id % 1000 = 1;
GO

DBCC FREEPROCCACHE
GO