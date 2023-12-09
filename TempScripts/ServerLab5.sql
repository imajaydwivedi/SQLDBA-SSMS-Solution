/* ServerLab5 
Top waits
SOS_SCHEDULER_YIELD -> 84% -> 88.1 ms Avg Time Per Wait
LCK_M_S -> 10.3% -> 411 ms Avg Time Per Wait


MAXDOP -> 4 -> 2
CTFP -> 50 -> 100

*/

USE [master]
GO
ALTER DATABASE [StackOverflow] SET READ_COMMITTED_SNAPSHOT ON WITH NO_WAIT
go

exec sp_BlitzIndex @DatabaseName = 'StackOverflow' , @Mode = 4

EXEC dbo.sp_BlitzIndex @DatabaseName='StackOverflow', @SchemaName='dbo', @TableName='Badges';
/*	[StackOverflow].[dbo].[Badges]. [CX][PK]. 27,802,198 rows; 1.3GB. 
	Reads: 10,028 (10,028 seek) Writes: 30,163
	10,028 singleton lookups; 0 scans/seeks; 0 deletes; 4,740 updates; 
	
	Index Hoarder: Unused NC Index with High Writes	
*/
DROP INDEX [IX_Id] ON [StackOverflow].[dbo].[Badges]; -- Reads: 0 Writes: 25,149
DROP INDEX [IX_UserId] ON [StackOverflow].[dbo].[Badges]; -- Reads: 0 Writes: 25,149
DROP INDEX [_dta_index_Badges_5_2105058535__K3_K2_K4] ON [StackOverflow].[dbo].[Badges]; -- Reads: 0 Writes: 25,149

/*
CREATE INDEX [IX_Id] ON [StackOverflow].[dbo].[Badges] ( [Id] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_UserId] ON [StackOverflow].[dbo].[Badges] ( [UserId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [_dta_index_Badges_5_2105058535__K3_K2_K4] ON [StackOverflow].[dbo].[Badges] ( [UserId], [Name], [Date] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
*/
GO

EXEC dbo.sp_BlitzIndex @DatabaseName='StackOverflow', @SchemaName='dbo', @TableName='Posts';
/* [StackOverflow].[dbo].[Posts]. [CX][PK]. 40,700,647 rows; 103.1GB; 17.6GB LOB
	Reads: 25,359 (25,359 seek) Writes: 20,382	
	25,359 singleton lookups; 0 scans/seeks; 0 deletes; 16,955 updates;
	
	Index Hoarder: Unused NC Index with High Writes
*/
DROP INDEX [_dta_index_Posts_5_85575343__K2] ON [StackOverflow].[dbo].[Posts]; -- Reads: 0 Writes: 5,069
DROP INDEX [IX_AcceptedAnswerId] ON [StackOverflow].[dbo].[Posts]; -- Reads: 0 Writes: 5,069
DROP INDEX [_dta_index_Posts_5_85575343__K2_K14] ON [StackOverflow].[dbo].[Posts]; -- Reads: 0 Writes: 5,069
DROP INDEX [_dta_index_Posts_5_85575343__K8] ON [StackOverflow].[dbo].[Posts]; -- Reads: 0 Writes: 5,069
DROP INDEX [IX_LastActivityDate_Includes] ON [StackOverflow].[dbo].[Posts]; -- Reads: 0 Writes: 5,069
DROP INDEX [IX_LastEditorUserId] ON [StackOverflow].[dbo].[Posts]; -- Reads: 0 Writes: 5,069
DROP INDEX [IX_OwnerUserId] ON [StackOverflow].[dbo].[Posts]; -- Reads: 0 Writes: 5,069
DROP INDEX [_dta_index_Posts_5_85575343__K14_K16_K7_K1_K2_17] ON [StackOverflow].[dbo].[Posts]; -- Reads: 0 Writes: 5,069
DROP INDEX [_dta_index_Posts_5_85575343__K14_K16_K1_K2] ON [StackOverflow].[dbo].[Posts]; -- Reads: 0 Writes: 5,069
DROP INDEX [IX_ParentId] ON [StackOverflow].[dbo].[Posts]; -- Reads: 0 Writes: 5,069
DROP INDEX [IX_PostTypeId] ON [StackOverflow].[dbo].[Posts]; -- Reads: 0 Writes: 5,069
DROP INDEX [_dta_index_Posts_5_85575343__K16_K7_K5_K14_17] ON [StackOverflow].[dbo].[Posts]; -- Reads: 0 Writes: 5,069
DROP INDEX [IX_ViewCount_Includes] ON [StackOverflow].[dbo].[Posts]; -- Reads: 0 Writes: 5,069
/*
CREATE INDEX [_dta_index_Posts_5_85575343__K2] ON [StackOverflow].[dbo].[Posts] ( [AcceptedAnswerId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_AcceptedAnswerId] ON [StackOverflow].[dbo].[Posts] ( [AcceptedAnswerId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [_dta_index_Posts_5_85575343__K2_K14] ON [StackOverflow].[dbo].[Posts] ( [AcceptedAnswerId], [OwnerUserId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [_dta_index_Posts_5_85575343__K8] ON [StackOverflow].[dbo].[Posts] ( [CreationDate] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
ALTER TABLE [StackOverflow].[dbo].[Posts] ADD CONSTRAINT [PK_Posts__Id] PRIMARY KEY CLUSTERED ( [Id] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_LastActivityDate_Includes] ON [StackOverflow].[dbo].[Posts] ( [LastActivityDate] ) INCLUDE ( [ViewCount]) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_LastEditorUserId] ON [StackOverflow].[dbo].[Posts] ( [LastEditorUserId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_OwnerUserId] ON [StackOverflow].[dbo].[Posts] ( [OwnerUserId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [_dta_index_Posts_5_85575343__K14_K16_K7_K1_K2_17] ON [StackOverflow].[dbo].[Posts] ( [OwnerUserId], [PostTypeId], [CommunityOwnedDate], [Id], [AcceptedAnswerId] ) INCLUDE ( [Score]) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [_dta_index_Posts_5_85575343__K14_K16_K1_K2] ON [StackOverflow].[dbo].[Posts] ( [OwnerUserId], [PostTypeId], [Id], [AcceptedAnswerId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_ParentId] ON [StackOverflow].[dbo].[Posts] ( [ParentId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_PostTypeId] ON [StackOverflow].[dbo].[Posts] ( [PostTypeId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [_dta_index_Posts_5_85575343__K16_K7_K5_K14_17] ON [StackOverflow].[dbo].[Posts] ( [PostTypeId], [CommunityOwnedDate], [ClosedDate], [OwnerUserId] ) INCLUDE ( [Score]) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_ViewCount_Includes] ON [StackOverflow].[dbo].[Posts] ( [ViewCount] ) INCLUDE ( [LastActivityDate]) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
*/
GO

EXEC dbo.sp_BlitzIndex @DatabaseName='StackOverflow', @SchemaName='dbo', @TableName='Users';
/*	[StackOverflow].[dbo].[Users]. [CX][PK]. 8,917,507 rows; 1.8GB; 1.0MB LOB
	Reads: 51,224 (51,224 seek) Writes: 46,155	
	51,224 singleton lookups; 0 scans/seeks; 0 deletes; 41,145 updates; 

	Index Hoarder: Unused NC Index with High Writes.
	Multiple Index Personalities: Borderline duplicate keys
	Workaholics: Top Recent Accesses (index-op-stats)
*/
DROP INDEX [_dta_index_Users_5_149575571__K7_K10_K1_5] ON [StackOverflow].[dbo].[Users]; -- Reads: 0 Writes: 41,082
DROP INDEX [IX_LastAccessDate] ON [StackOverflow].[dbo].[Users]; -- Reads: 0 Writes: 41,082
DROP INDEX [IX_LastAccessDate_DisplayName_Reputation] ON [StackOverflow].[dbo].[Users]; -- Reads: 0 Writes: 41,082
DROP INDEX [<Name of Missing Index, sysname,>] ON [StackOverflow].[dbo].[Users]; -- Reads: 0 Writes: 41,082
DROP INDEX [IX_Reputation_Includes] ON [StackOverflow].[dbo].[Users]; -- Reads: 0 Writes: 41,082
DROP INDEX [IX_Views_Includes] ON [StackOverflow].[dbo].[Users]; -- Reads: 0 Writes: 41,082
/*
CREATE INDEX [_dta_index_Users_5_149575571__K7_K10_K1_5] ON [StackOverflow].[dbo].[Users] ( [EmailHash], [Reputation], [Id] ) INCLUDE ( [DisplayName]) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_LastAccessDate] ON [StackOverflow].[dbo].[Users] ( [LastAccessDate] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_LastAccessDate_DisplayName_Reputation] ON [StackOverflow].[dbo].[Users] ( [LastAccessDate], [DisplayName], [Reputation] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [<Name of Missing Index, sysname,>] ON [StackOverflow].[dbo].[Users] ( [Reputation] ) INCLUDE ( [Views]) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_Reputation_Includes] ON [StackOverflow].[dbo].[Users] ( [Reputation] ) INCLUDE ( [Views]) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_Views_Includes] ON [StackOverflow].[dbo].[Users] ( [Views] ) INCLUDE ( [Reputation]) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
*/
go

EXEC dbo.sp_BlitzIndex @DatabaseName='StackOverflow', @SchemaName='dbo', @TableName='Audit';
/*	[StackOverflow].[dbo].[Audit]. [HEAP]. 3,094,164 rows; 324.1MB
	Reads: 66,424 (66,424 scan) Writes: 320,530	
	0 singleton lookups; 66,427 scans/seeks; 0 deletes; 0 updates; 
	
	Aggressive Under-Indexing: Total lock wait time > 5 minutes (row + page)
	Self Loathing Indexes: Large Active Heap
	Index Hoarder: Wide Tables: 35+ cols or > 2000 non-LOB bytes
	Index Hoarder: Addicted to Nulls
	Index Hoarder: Addicted to strings
	Abnormal Psychology: Recently Created Tables/Indexes (1 week)
	Workaholics: Scan-a-lots (index-usage-stats)
	Workaholics: Top Recent Accesses (index-op-stats)
*/
CREATE CLUSTERED INDEX ci_Audit ON [StackOverflow].[dbo].[Audit] (UpdateDate, FieldName)
	WITH (MAXDOP = 4, FILLFACTOR=100, DATA_COMPRESSION=PAGE)
/*
*/
go

EXEC dbo.sp_BlitzIndex @DatabaseName='StackOverflow', @SchemaName='dbo', @TableName='Comments';
/*	[StackOverflow].[dbo].[Comments]. [CX][PK]. 66,432,641 rows; 21.1GB
	Reads: 20,364 (20,364 seek) Writes: 15,325	
	20,364 singleton lookups; 0 scans/seeks; 0 deletes; 12,275 updates; 

*/
DROP INDEX [IX_Id] ON [StackOverflow].[dbo].[Comments];
DROP INDEX [IX_PostId] ON [StackOverflow].[dbo].[Comments];
DROP INDEX [IX_UserId] ON [StackOverflow].[dbo].[Comments];
DROP INDEX [_dta_index_Comments_5_2137058649__K6_K2_K3] ON [StackOverflow].[dbo].[Comments];
/*
CREATE INDEX [IX_Id] ON [StackOverflow].[dbo].[Comments] ( [Id] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_PostId] ON [StackOverflow].[dbo].[Comments] ( [PostId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_UserId] ON [StackOverflow].[dbo].[Comments] ( [UserId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [_dta_index_Comments_5_2137058649__K6_K2_K3] ON [StackOverflow].[dbo].[Comments] ( [UserId], [CreationDate], [PostId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
*/
go

EXEC dbo.sp_BlitzIndex @DatabaseName='StackOverflow', @SchemaName='dbo', @TableName='Votes';
/*	[StackOverflow].[dbo].[Votes]. [CX][PK]. 150,784,380 rows; 5.3GB
	Reads: 10,092 (10,092 seek) Writes: 5,046	
	10,092 singleton lookups; 0 scans/seeks; 0 deletes; 4,349 updates;
*/
DROP INDEX [IX_PostId_UserId] ON [StackOverflow].[dbo].[Votes];
DROP INDEX [IX_UserId] ON [StackOverflow].[dbo].[Votes];
DROP INDEX [_dta_index_Votes_5_181575685__K3_K2_K5] ON [StackOverflow].[dbo].[Votes];
DROP INDEX [IX_VoteTypeId] ON [StackOverflow].[dbo].[Votes];
/*
CREATE INDEX [IX_PostId_UserId] ON [StackOverflow].[dbo].[Votes] ( [PostId], [UserId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_UserId] ON [StackOverflow].[dbo].[Votes] ( [UserId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [_dta_index_Votes_5_181575685__K3_K2_K5] ON [StackOverflow].[dbo].[Votes] ( [UserId], [PostId], [VoteTypeId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
CREATE INDEX [IX_VoteTypeId] ON [StackOverflow].[dbo].[Votes] ( [VoteTypeId] ) WITH (FILLFACTOR=100, ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);
*/
go


create nonclustered index nci_FieldName_TableName_UpdateDate on StackOverflow.dbo.Audit (FieldName, TableName, UpdateDate)
	with (fillfactor=80, data_compression=page, maxdop=4)
go

USE [StackOverflow]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROC [dbo].[usp_AuditReport] @TableName VARCHAR(128) = NULL, @FieldName VARCHAR(128) = NULL, 
	@StartDate DATE, @EndDate DATE, @PageNumber INT = 1, @PageSize INT = 100 AS
BEGIN
	declare @sql nvarchar(4000);
	declare @params nvarchar(2000);

	set @params = N'@PageNumber int, @PageSize int, @EndDate date, @StartDate date, @FieldName nvarchar(128), @TableName nvarchar(128)';

	set @sql = '/* [StackOverflow].[dbo].[usp_AuditReport] */ SELECT * FROM dbo.Audit
  WHERE 1=1
	'+(CASE WHEN @TableName IS NOT NULL THEN '' ELSE '--' END)+'AND TableName = @TableName
    '+(CASE WHEN @FieldName IS NOT NULL THEN '' ELSE '--' END)+'AND FieldName = @FieldName
	'+(CASE WHEN @StartDate IS NOT NULL THEN '' ELSE '--' END)+'AND UpdateDate >= @StartDate
	'+(CASE WHEN @EndDate IS NOT NULL THEN '' ELSE '--' END)+'AND UpdateDate <= @EndDate
  ORDER BY UpdateDate, FieldName
  OFFSET ((@PageNumber - 1) * @PageSize) ROWS
  FETCH NEXT @PageSize ROWS ONLY;'

	exec sp_executesql @sql, @params, @PageNumber, @PageSize, @EndDate, @StartDate, @FieldName, @TableName;
END
GO

declare @PageNumber int = 1
declare @PageSize int = 100
declare @EndDate date = '2018-12-31'
declare @StartDate date = '2018-01-01'
declare @FieldName varchar(128) = N'Text'
declare @TableName varchar(128) = N'Comments'

exec dbo.[usp_AuditReport] @TableName, @FieldName, @StartDate, @EndDate, @PageNumber, @PageSize
go


USE [StackOverflow]
GO

ALTER TRIGGER [dbo].[TR_Votes_AUDIT] ON [dbo].[Votes] FOR UPDATE
AS

DECLARE @bit INT ,
       @field INT ,
       @maxfield INT ,
       @char INT ,
       @fieldname VARCHAR(128) ,
       @TableName VARCHAR(128) ,
       @PKCols VARCHAR(1000) ,
       @sql NVARCHAR(max), -- Ajay: NVARCHAR for sp_executesql
       @UpdateDate datetime , -- Ajay: Datatime change
       @UserName VARCHAR(128) ,
       @Type CHAR(1) ,
       @PKSelect VARCHAR(1000)

-- Ajay: Define parameters
DECLARE @params nvarchar(max);
set @params = N'@bit INT, @field INT, @maxfield INT, @char INT, @fieldname VARCHAR(128), @TableName VARCHAR(128), @PKCols VARCHAR(1000), @UpdateDate datetime, @UserName VARCHAR(128), @Type CHAR(1), @PKSelect VARCHAR(100)'

--You will need to change @TableName to match the table to be audited. 
-- Here we made GUESTS for your example.
SELECT @TableName = 'Votes'

-- date and user
SELECT         @UserName = SYSTEM_USER ,
       @UpdateDate = getdate() --CONVERT (NVARCHAR(30),GETDATE(),126)

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

				-- Ajay: Parameterize query using sp_executesql
               SELECT @sql = '
insert Audit ( Type, TableName, PK, FieldName, OldValue, NewValue, UpdateDate, UserName )
select @Type, @TableName, @PKSelect, @fieldname, convert(varchar(1000),d.'+@fieldname+'), convert(varchar(1000),i.'+@fieldname+'), @UpdateDate, @UserName '
       + ' from #ins i full outer join #del d'
       + @PKCols
       + ' where i.' + @fieldname + ' <> d.' + @fieldname 
       + ' or (i.' + @fieldname + ' is null and  d.'
                                + @fieldname
                                + ' is not null)' 
       + ' or (i.' + @fieldname + ' is not null and  d.' 
                                + @fieldname
                                + ' is null)' 

            --print @sql
            EXEC sp_executesql @sql, @params, @bit, @field, @maxfield, @char, @fieldname, @TableName, @PKCols, @UpdateDate, @UserName, @Type, @PKSelect;
       END
END
GO