/*
Fundamentals of Columnstore: How Data is Selected
v1.1 - 2021-11-08
https://www.BrentOzar.com/go/columnfund


This demo requires:
* SQL Server 2016 or newer
* Stack Overflow database 2018-06 version: https://www.BrentOzar.com/go/querystack

This first RAISERROR is just to make sure you don't accidentally hit F5 and
run the entire script. You don't need to run this:
*/
RAISERROR(N'Oops! No, don''t just hit F5. Run these demos one at a time.', 20, 1) WITH LOG;
GO


/* I'm using the large Stack database: */
USE StackOverflow;
GO
DropIndexes @TableName = 'Users';
GO

/* Turn on actual plans and start in 2016 compat level: */
SET STATISTICS IO, TIME ON;
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 130
GO


/* Recreate & reload the table. I know, you might already have it built, but
trust me, this is going to be important later. Start with a fresh one. */
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
/* Load with the same amount of data: */
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



/* Let's say we only want to find the top 1 CreationDate: */
SELECT TOP 1 CreationDate
  FROM dbo.Users
  ORDER BY CreationDate DESC;
GO

SELECT TOP 1 CreationDate
  FROM dbo.Users_columnstore
  ORDER BY CreationDate DESC;
GO

/* Compare those queries by:

* Logical reads (including lob logical reads)
* Duration
* CPU time
* Parallelism
* Memory grant 

At first glance, it seems like the columnstore index wins.

But it gets a little trickier. I'm going to rewrite those
two queries - will they get the same plans in my new way? */

SELECT TOP 1 CreationDate
  FROM dbo.Users
  ORDER BY CreationDate DESC;

SELECT MAX(CreationDate)
  FROM dbo.Users;

SELECT TOP 1 CreationDate
  FROM dbo.Users_columnstore
  ORDER BY CreationDate DESC;

SELECT MAX(CreationDate)
  FROM dbo.Users_columnstore;
GO

/* The plans, logical reads, and times are all different
for both rowstore & columnstore tables.

This isn't a new thing: different queries = different plans.

For the rest of this, I'm going to focus on reporting
style queries. They will be the kinds of queries where
columnstore usually does better - but I'm not trying
to make columnstore look good.

So let's use the MAX queries.

Will the rowstore table do well if it has an index?
*/
CREATE INDEX CreationDate ON dbo.Users(CreationDate);
GO


SELECT MAX(CreationDate)
  FROM dbo.Users;

SELECT MAX(CreationDate)
  FROM dbo.Users_columnstore;
GO

/* Compare those queries by:

* Logical reads (including lob logical reads)
* Duration
* CPU time
* Parallelism
* Memory grant 


If:

* You can predict the columns queries will filter/sort on
* You can keep that number down relatively low (the 5 & 5 guideline)
* You're doing updates on the table

Then it makes more sense to just do normal rowstore indexes.

But what if:

* You can't predict the filter/sort columns
* You can't keep that number down
* The queries don't bring back all of the columns
* The data is loaded periodically (deletes/inserts, no updates)

Let's try a reporting-style query that uses more than
just the CreationDate column - it also gets Reputation:
*/
SELECT YEAR(CreationDate) AS Yr, MONTH(CreationDate) AS Mo,
	COUNT(*) AS UsersCreated, AVG(Reputation) AS AvgReputation
	FROM dbo.Users
	GROUP BY YEAR(CreationDate), MONTH(CreationDate)
	ORDER BY YEAR(CreationDate), MONTH(CreationDate);

SELECT YEAR(CreationDate) AS Yr, MONTH(CreationDate) AS Mo,
	COUNT(*) AS UsersCreated, AVG(Reputation) AS AvgReputation
	FROM dbo.Users_columnstore
	GROUP BY YEAR(CreationDate), MONTH(CreationDate)
	ORDER BY YEAR(CreationDate), MONTH(CreationDate);
GO
/* Compare those queries by:

* Logical reads (including lob logical reads)
* Duration
* CPU time
* Parallelism
* Memory grant 

So why is the columnstore query faster? 

* It reads less columns of the table
* It has less data to group/sort
* It does the work in a more efficient way (batch operation)

In 2019 compat level, rowstore indexes can get batch
execution mode too. If you're on 2019, see it:
*/
ALTER DATABASE [StackOverflow] SET COMPATIBILITY_LEVEL = 150
GO
SELECT YEAR(CreationDate) AS Yr, MONTH(CreationDate) AS Mo,
	COUNT(*) AS UsersCreated, AVG(Reputation) AS AvgReputation
	FROM dbo.Users
	GROUP BY YEAR(CreationDate), MONTH(CreationDate)
	ORDER BY YEAR(CreationDate), MONTH(CreationDate)
	OPTION (USE HINT('DISALLOW_BATCH_MODE'));	/* Simulates 2017 execution */

SELECT YEAR(CreationDate) AS Yr, MONTH(CreationDate) AS Mo,
	COUNT(*) AS UsersCreated, AVG(Reputation) AS AvgReputation
	FROM dbo.Users
	GROUP BY YEAR(CreationDate), MONTH(CreationDate)
	ORDER BY YEAR(CreationDate), MONTH(CreationDate);

SELECT YEAR(CreationDate) AS Yr, MONTH(CreationDate) AS Mo,
	COUNT(*) AS UsersCreated, AVG(Reputation) AS AvgReputation
	FROM dbo.Users_columnstore
	GROUP BY YEAR(CreationDate), MONTH(CreationDate)
	ORDER BY YEAR(CreationDate), MONTH(CreationDate);
GO
/* 
The takeaway: 2019's batch mode on rowstore indexes
gives you a lot of columnstore's low-CPU advantage
without actually having to use columnstore.

In this edge case, don't judge success by duration
alone: the columnstore query may not have gone
parallel. Judge it by CPU time overall & reads. 
(These differences will grow larger as we move
to larger tables.)

Let's go back to 2016 compat mode to level the
playing field: */
ALTER DATABASE [StackOverflow] SET COMPATIBILITY_LEVEL = 130
GO

/*
However, columnstore has some other cool tricks up
its sleeve, especially around what data it reads.
Look at the reporting query again: */

SELECT YEAR(CreationDate) AS Yr, MONTH(CreationDate) AS Mo,
	COUNT(*) AS UsersCreated, AVG(Reputation) AS AvgReputation
	FROM dbo.Users_columnstore
	GROUP BY YEAR(CreationDate), MONTH(CreationDate)
	ORDER BY YEAR(CreationDate), MONTH(CreationDate);
GO
/* To execute this query, we have to read all of
the row groups because we don't have a WHERE.

But what if we add one? */
SELECT YEAR(CreationDate) AS Yr, MONTH(CreationDate) AS Mo,
	COUNT(*) AS UsersCreated, AVG(Reputation) AS AvgReputation
	FROM dbo.Users_columnstore
	WHERE CreationDate BETWEEN '2008-01-01' AND '2011-01-01'
	GROUP BY YEAR(CreationDate), MONTH(CreationDate)
	ORDER BY YEAR(CreationDate), MONTH(CreationDate);
GO

/* Which row groups & segments will we read: */
sp_BlitzIndex @TableName = 'Users_columnstore',
	@ShowColumnstoreOnly = 1;
GO

/* Run the report query with the filter, and look
at the statistics io output. Read these:
Segment reads: 10
Segment skipped: 0

Hmm, why did SQL Server have to read all of them?

You would think that CreationDate would march
upwards, always going up, as Ids went up. You
would be wrong: */
SELECT MIN(CreationDate) FROM dbo.Users WHERE Id BETWEEN 1 AND 1000000;
SELECT MIN(CreationDate) FROM dbo.Users WHERE Id BETWEEN 1000001 AND 2000000;


/* Look at these CreationDates: */
SELECT * FROM dbo.Users WHERE Id BETWEEN 1384642 AND 1384662 ORDER BY Id;

/* And no, it's not a bug:
https://stackoverflow.com/users/1384651/   Created in 2012
https://stackoverflow.com/users/1384652/   Created in 2008

     ___
   _/ ..\
  ( \  0/__
   \    \__)
   /     \
  /      _\
  `"""""``


We CAN get segment elimination if we specify Ids:
*/
SELECT YEAR(CreationDate) AS Yr, MONTH(CreationDate) AS Mo,
	COUNT(*) AS UsersCreated, AVG(Reputation) AS AvgReputation
	FROM dbo.Users_columnstore
	WHERE Id BETWEEN -1 AND 2000000
	GROUP BY YEAR(CreationDate), MONTH(CreationDate)
	ORDER BY YEAR(CreationDate), MONTH(CreationDate);
GO
/* Segment reads 3, segment skipped 7.

Because only 3 segments have those Ids in them: */
sp_BlitzIndex @TableName = 'Users_columnstore',
	@ShowColumnstoreOnly = 1;
GO



/* But this leads to a big columnstore challenge:
if we really want the best performance, SQL Server
would love to avoid reading all the segments.

Partitioned tables have "partition elimination"
Columnstore indexes have "segment elimination"
  (which is really "row group elimination")

And they're both hard work.

But take heart: the big bang for the buck is
that you only have to read the columns you want,
and that's still a win even if we can't eliminate
row groups.

Now, let's delete, update, and insert some rows,
and see how that effects our query.
*/
DELETE dbo.Users_columnstore
	WHERE Location = N'Paris, France';
GO
UPDATE dbo.Users
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


/* Now run our report query again with the date filter: */
SELECT YEAR(CreationDate) AS Yr, MONTH(CreationDate) AS Mo,
	COUNT(*) AS UsersCreated, AVG(Reputation) AS AvgReputation
	FROM dbo.Users_columnstore
	WHERE CreationDate BETWEEN '2008-01-01' AND '2011-01-01'
	GROUP BY YEAR(CreationDate), MONTH(CreationDate)
	ORDER BY YEAR(CreationDate), MONTH(CreationDate);
GO
/* Check your logical reads - segments have been skipped!

Because the newly created segments have new CreationDates
only, and no "old" users, so they get skipped: */
sp_BlitzIndex @TableName = 'Users_columnstore',
	@ShowColumnstoreOnly = 1;
GO


/* However, if we want to filter by anything other than
CreationDate - like, say, Reputation - will we be able
to eliminate segments? */
SELECT YEAR(CreationDate) AS Yr, MONTH(CreationDate) AS Mo,
	COUNT(*) AS UsersCreated, AVG(Reputation) AS AvgReputation
	FROM dbo.Users_columnstore
	WHERE Reputation BETWEEN 1000 AND 10000
	GROUP BY YEAR(CreationDate), MONTH(CreationDate)
	ORDER BY YEAR(CreationDate), MONTH(CreationDate);
GO


/* What we learned in this module:

Rowstore indexes are a better fit when: 

* You can predict the columns queries will filter/sort on
* You can keep that number down relatively low (the 5 & 5 guideline)
* The queries are bringing back a lot of columns (SELECT *)
* You're doing updates on the table
* You're on 2019 compat level, get batch mode on rowstore

When we use columnstore indexes:

* The syntax we use matters (TOP vs MAX) just like
  it does with rowstore - we still tune queries

* Columnstore goes faster when we eliminate
  row groups and column segments

* It's going to be hard to get segment elimination
  as we delete/update/insert data

* Query performance will degrade over time, and
  we'll need to fix that with index maintenance
  and careful loading

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