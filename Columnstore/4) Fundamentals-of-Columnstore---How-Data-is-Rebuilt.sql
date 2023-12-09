/*
Fundamentals of Columnstore: How Data is Rebuilt
v1.3 - 2021-11-08
https://www.BrentOzar.com/go/columnfund


This demo requires:
* SQL Server 2016 or newer
* Stack Overflow database 2018-06 version: https://www.BrentOzar.com/go/querystack

This first RAISERROR is just to make sure you don't accidentally hit F5 and
run the entire script. You don't need to run this:
*/
RAISERROR(N'Oops! No, don''t just hit F5. Run these demos one at a time.', 20, 1) WITH LOG;
GO


USE StackOverflow;
SET STATISTICS TIME, IO ON;
GO


/* In case you need to reload the table and simulate
the delete/update/insert loads we've been running: */ 
DROP TABLE IF EXISTS [dbo].[Users_columnstore];
GO
CREATE TABLE [dbo].[Users_columnstore](
	[Id] [int] IDENTITY(1,1),
	[AboutMe] [nvarchar](4000) NULL,
	[Age] [int] NULL,
	[CreationDate] [datetime] NOT NULL,
	[DisplayName] [nvarchar](40) NOT NULL,
	[DownVotes] [int] NOT NULL,
	[EmailHash] [nvarchar](40) NULL,
	[LastAccessDate] [datetime] NOT NULL,
	[Location] [nvarchar](100) NULL,
	[Reputation] [int] NOT NULL,
	[UpVotes] [int] NOT NULL,
	[Views] [int] NOT NULL,
	[WebsiteUrl] [nvarchar](200) NULL,
	[AccountId] [int] NULL)
GO
CREATE CLUSTERED COLUMNSTORE INDEX CCI ON dbo.Users_Columnstore;
GO
SET IDENTITY_INSERT dbo.Users_columnstore ON;
GO
INSERT INTO dbo.Users_columnstore([Id], [AboutMe], [Age], [CreationDate], [DisplayName], [DownVotes], 
		[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId])
	SELECT [Id], LEFT([AboutMe],4000), [Age], [CreationDate], [DisplayName], [DownVotes], 
		[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId]
	FROM dbo.Users;
GO
SET IDENTITY_INSERT dbo.Users_columnstore OFF;
GO
DELETE dbo.Users_columnstore
	WHERE Location = N'Paris, France';
GO
UPDATE dbo.Users_columnstore
	SET LastAccessDate = GETDATE()
	WHERE Location = N'London, United Kingdom';
GO
INSERT INTO [dbo].[Users_columnstore]([AboutMe], [Age], [CreationDate], [DisplayName], [DownVotes], 
	[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId])
SELECT TOP 1000 LEFT([AboutMe],4000), [Age], GETDATE() AS CreationDate, [DisplayName], [DownVotes], 
	[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId]
FROM dbo.Users;
GO 5
INSERT INTO [dbo].[Users_columnstore]([AboutMe], [Age], [CreationDate], [DisplayName], [DownVotes], 
	[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId])
SELECT TOP 10000 LEFT([AboutMe],4000), [Age], GETDATE() AS CreationDate, [DisplayName], [DownVotes], 
	[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId]
FROM dbo.Users;
GO 5
INSERT INTO [dbo].[Users_columnstore]([AboutMe], [Age], [CreationDate], [DisplayName], [DownVotes], 
	[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId])
SELECT TOP 1000000 LEFT([AboutMe],4000), [Age], GETDATE() AS CreationDate, [DisplayName], [DownVotes], 
	[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId]
FROM dbo.Users;
GO





/* You've been changing data for a while.

Take a look at how your data is organized now: */
sp_BlitzIndex @TableName = 'Users_columnstore',
	@ShowColumnstoreOnly = 1;
GO

/* Note:
* Row groups 0-9 are partitioned by Id
* The rest aren't

* Note the number of rows in each row group
* Note the number of deleted_rows, too

Let's find out what reorganizing does:
*/
ALTER INDEX CCI ON dbo.Users_columnstore REORGANIZE;
GO
/* What changed? */
sp_BlitzIndex @TableName = 'Users_columnstore',
	@ShowColumnstoreOnly = 1;

/* Hmm, well, not much. Here's how SQL Server
decides what it's going to do when reorg'ing:
https://docs.microsoft.com/en-us/archive/blogs/sqlserverstorageengine/columnstore-index-merge-policy-for-reorganize

People were angry about that, so SQL 2019 CU9
added trace flags that can influence the choices:
https://techcommunity.microsoft.com/t5/sql-server-support/new-trace-flags-for-better-maintenance-of-deleted-rows-in/ba-p/2127034

How about a rebuild? */
ALTER TABLE dbo.Users_columnstore REBUILD;
GO


/* 
That took a lot of time for a 1GB table.

Visualize it again: */
sp_BlitzIndex @TableName = 'Users_columnstore',
	@ShowColumnstoreOnly = 1;
GO

/* Now note:
* The sizes of each row group
* The row groups aren't partitioned by Id anymore either
* None of the columns are really partitioned

So as a result, if our select queries filter by
ANYTHING, they're not going to get segment elimination: */

ALTER TABLE dbo.Users_columnstore REBUILD;
GO
/* And then visualize it again: */
sp_BlitzIndex @TableName = 'Users_columnstore',
	@ShowColumnstoreOnly = 1;
GO
/* Wildly different sizes in row groups now,
and wildly different "partitioning" - everything
is stored everywhere. 

With the 9M row User table, this isn't a big deal.
In real-world sized tables, it is, because you want
to get row group & segment elimination.


This is a known issue with columnstore rebuilds,
especially multi-threaded parallel rebuilds:
https://feedback.azure.com/forums/908035-sql-server/suggestions/32907184-multi-threaded-rebuilds-of-clustered-columnstore-i

Azure Synapse Analytics (formerly known as 
Azure SQL Data Warehouse) added support for ordered
columnstore indexes in mid-2019:
https://docs.microsoft.com/en-us/sql/t-sql/statements/create-columnstore-index-transact-sql?

With this syntax:
*/
CREATE CLUSTERED COLUMNSTORE INDEX CCI ON dbo.Users
ORDER ( DisplayName );

/*
So maybe we'll get it in SQL Server soon, but...
we don't have it yet.

So for now, in 2020, if we want elimination, we
have to think about:

* What column do we want to use for elimination?
  (Only get one column, like a partitioning key.)

* Then, how do we get columnstore indexes to "sort"
  on that column when rebuilding?

The trick is to think about how an index build works.
Look at the actual execution plan for this:
*/
ALTER TABLE dbo.Users_columnstore REBUILD;
GO
/* Note:

* SQL Server reads from the existing object
  (in this case, the columnstore index - but it
  doesn't have to be.)

* The query goes parallel, which means the work
  was broken up by thread before we started.
  Each thread works on its own part of the index.


Let's say we decide we want segment elimination
for this query, ranges of CreationDates: */
SELECT YEAR(CreationDate) AS Yr, MONTH(CreationDate) AS Mo,
	COUNT(*) AS UsersCreated, AVG(Reputation) AS AvgReputation
	FROM dbo.Users_columnstore
	WHERE CreationDate BETWEEN '2008-01-01' AND '2009-01-01'
	GROUP BY YEAR(CreationDate), MONTH(CreationDate)
	ORDER BY YEAR(CreationDate), MONTH(CreationDate);
GO
/* Right now, we're reading most of the segments.
Can we rebuild Users_columnstore in a way that the
row groups are organized by CreationDate? 

Right now they're not: */
sp_BlitzIndex @TableName = 'Users_columnstore',
	@ShowColumnstoreOnly = 1;
GO

/* This is going to sound terrifying: */
DROP INDEX CCI ON dbo.Users_columnstore;
GO

/* Create the clustered index in the order you want.
NOTE THAT THIS IS NOT A COLUMNSTORE INDEX. */

CREATE CLUSTERED INDEX CCI ON dbo.Users_columnstore(CreationDate);
GO
/* Recreate the clustered columnstore index: */
CREATE CLUSTERED COLUMNSTORE INDEX CCI ON dbo.Users_columnstore
WITH (DROP_EXISTING = ON, MAXDOP = 1); /* More on the MAXDOP hint later */
GO

/* Is it organized by CreationDate? */
sp_BlitzIndex @TableName = 'Users_columnstore',
	@ShowColumnstoreOnly = 1;
GO


/* Do we get segment elimination? */
SELECT YEAR(CreationDate) AS Yr, MONTH(CreationDate) AS Mo,
	COUNT(*) AS UsersCreated, AVG(Reputation) AS AvgReputation
	FROM dbo.Users_columnstore
	WHERE CreationDate BETWEEN '2008-01-01' AND '2009-01-01'
	GROUP BY YEAR(CreationDate), MONTH(CreationDate)
	ORDER BY YEAR(CreationDate), MONTH(CreationDate);
GO


/* What we learned in this module:

Columnstore indexes have 4 advantages:

1: Batch mode execution: but 2019 gives you that on rowstore

2: Compression (because the table is smaller thanks to
   how each column is stored in segments, and if the
   data is highly repetitive, then it compresses well)

3: Segment elimination: only query the columns you need
   (makes the most sense in wide tables)

4: Rowgroup elimination: but you only get it on 1 column,
   and only after the index is built the first time,
   and much less over time, and if you want to maintain
   this advantage, you have to really work hard on index
   maintenance to get it


If you're on SQL Server 2019, just start with
compat level 150 and get batch mode execution.

If you're on earlier versions, segment elimination
alone may be good enough for you on wide tables.

However, if:
* Batch mode doesn't help much
* Segment (column) elimination doesn't help much

Then don't bank on rowgroup elimination alone to
help: it's hard to get, and hard to maintain. You
can't just "do an index rebuild" and fix it: you
really need to either:
* Design your loads to load data in exactly the
  same groups that you want to eliminate, or

* When you need to rebuild the table, be prepared
  to drop the existing index, recreate a new one,
  and essentially reload the table from scratch

This is why data warehouse fact tables that are
queried by SalesDate are such a good fit for
clustered columnstore indexes: we load them one
SalesDate at a time, and then query them for
ranges of SalesDates.

If you do really want rowgroup elimination, here
are links on how to get it and maintain it as you
continue to load more data over time:

https://orderbyselectnull.com/2017/08/07/rowgroup-elimination/

https://joyfulcraftsmen.com/blog/cci-how-to-load-data-for-better-columnstore-segment-elimination/

https://www.sqlservercentral.com/steps/stairway-to-columnstore-indexes-level-7-optimizing-nonclustered-columnstore-indexes

How parallelism affects inserts:
http://www.nikoport.com/2015/08/19/columnstore-indexes-part-62-parallel-data-insertion/

How parallelism affects compression:
https://orderbyselectnull.com/2017/11/21/a-columnstore-compression-magic-trick/

Programmatically picking the best column to sort on:
http://www.nikoport.com/2017/08/27/columnstore-indexes-part-110-the-best-column-for-sorting-columnstore-index-on/

Advanced loading with partitioning:
https://joyfulcraftsmen.com/blog/cci-data-loading-considerations-with-partitioned-tables-and-cci/

Niko Nuegebauer's Columnstore Index Script Library
to diagnose fragmentation and alignment:
https://github.com/NikoNeugebauer/CISL
*/


/*
License: Creative Commons Attribution-ShareAlike 4.0 Unported (CC BY-SA 4.0)
More info: https://creativecommons.org/licenses/by-sa/4.0/

You are free to:
* Share - copy and redistribute the material in any medium or format
* Adapt - remix, transform, and build upon the material for any purpose, even 
  commercially

Under the following terms:
* Attribution - You must give appropriate credit, provide a link to the license, 
  and indicate if changes were made. You may do so in any reasonable manner, 
  but not in any way that suggests the licensor endorses you or your use.
* ShareAlike - If you remix, transform, or build upon the material, you must
  distribute your contributions under the same license as the original.
* No additional restrictions — You may not apply legal terms or technological 
  measures that legally restrict others from doing anything the license permits.
*/