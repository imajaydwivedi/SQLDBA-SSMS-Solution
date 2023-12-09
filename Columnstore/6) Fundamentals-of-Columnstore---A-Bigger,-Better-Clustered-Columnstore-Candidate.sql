/*
Fundamentals of Columnstore: A Bigger, Better Clustered Columnstore Candidate
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
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 130;
GO

/* The Users table isn't a good fit for 
clustered columnstore because it's tiny.

What are the other tables in Stack Overflow? */
sp_BlitzIndex @Mode = 2, @SortOrder = 'size'
GO

/* Great candidates:

* Over 100M rows
* Over 100GB in size
* Insert-heavy, ideally loaded in batches
* Never updated
* Lots of columns
* Analytical queries


None of the Stack tables really fit.

One of them is kinda close: dbo.Votes.
* Insert-only (votes aren't updated or deleted)
* 150M rows (but it's really not that many per day)
* Analytical-style queries: sometimes we query by
  PostId, sometimes by UserId, sometimes by date

Let's make a few assumptions:
* New rows are inserted with CreationDate = GETDATE()

* Data goes into a caching system on the front end,
  and then we import it into this table hourly.
  Each hour, we load between 5K and 500K new rows.

* When we query, we want everything to be fast,
  but we want segment elimination by PostId because
  we run a lot of queries like this:
*/
SELECT VoteTypeId, YEAR(CreationDate) AS Yr, COUNT(*) AS VotesCast
  FROM dbo.Votes
  WHERE PostId = 9033
  GROUP BY VoteTypeId, YEAR(CreationDate)
  ORDER BY VoteTypeId, YEAR(CreationDate);

/* Let's create a columnstore copy of the table.

Note that I'm only inserting 10,000,000 rows,
not the entire table. I want a fast demo. */
DROP TABLE IF EXISTS [dbo].[Votes_columnstore];
GO
CREATE TABLE [dbo].[Votes_columnstore](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[PostId] [int] NOT NULL,
	[UserId] [int] NULL,
	[BountyAmount] [int] NULL,
	[VoteTypeId] [int] NOT NULL,
	[CreationDate] [datetime] NOT NULL,
	INDEX CCI CLUSTERED COLUMNSTORE
);
GO
SET IDENTITY_INSERT dbo.Votes_columnstore ON;
GO
INSERT INTO dbo.Votes_columnstore 
	(Id, PostId, UserId, BountyAmount, VoteTypeId, CreationDate)
	SELECT TOP 10000000		/* For a more realistic (but WAY slower demo), remove the TOP */
	Id, PostId, UserId, BountyAmount, VoteTypeId, CreationDate
	FROM dbo.Votes;
GO
SET IDENTITY_INSERT dbo.Votes_columnstore OFF;
GO
/* When it finishes, look at the segment alignment.
What column is the data organized by? Why?
If we wanted it organized by something else,
how would we get it? */
sp_BlitzIndex @TableName = 'Votes_columnstore',
	@ShowColumnstoreOnly = 1;
GO

/* If our goal is to get segment elimination for this: */
SELECT VoteTypeId, YEAR(CreationDate) AS Yr, COUNT(*) AS VotesCast
  FROM dbo.Votes_columnstore
  WHERE PostId = 9033
  GROUP BY VoteTypeId, YEAR(CreationDate)
  ORDER BY VoteTypeId, YEAR(CreationDate);

/* Then how would we get it? 

If you only loaded the top 10,000,000 rows,
then you only got 10 row groups, so elimination
isn't a big deal. But in the real table with
>100M rows, and as the table grows, this is big.
*/


/* To get the data sorted, we need to:
* Fetch it from a source that's already sorted
  in the right order. In this case, I can't just
  insert from dbo.Votes - that's sorted by Id.
  I'm going to need to build a copy of the table
  that has the data I want, sorted for me:

* Create a clustered index on the column where
  we want segment elimination
* Load the data
* Create a new clustered columnstore index
  (using the old clustered index as the source)

The initial load of >100M rows will take 4-6 minutes:
*/
DROP TABLE IF EXISTS [dbo].[Votes_columnstore];
GO
CREATE TABLE [dbo].[Votes_columnstore](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[PostId] [int] NOT NULL,
	[UserId] [int] NULL,
	[BountyAmount] [int] NULL,
	[VoteTypeId] [int] NOT NULL,
	[CreationDate] [datetime] NOT NULL,
	INDEX CCI CLUSTERED (PostId)
);
GO
SET IDENTITY_INSERT dbo.Votes_columnstore ON;
GO
INSERT INTO dbo.Votes_columnstore 
	(Id, PostId, UserId, BountyAmount, VoteTypeId, CreationDate)
	SELECT /* TOP 10000000	*/	/* For a faster demo, uncomment this */
	Id, PostId, UserId, BountyAmount, VoteTypeId, CreationDate
	FROM dbo.Votes;
GO
SET IDENTITY_INSERT dbo.Votes_columnstore OFF;
GO

/* Now create the clustered columnstore
because the source data will be sorted on PostId,
since that's the current clustered index of the table.

Run the below with actual plans, and while it runs,
watch the memory grant & usage in another window
with sp_BlitzWho showing the live query plans.

This takes 4-6 minutes too: */
CREATE CLUSTERED COLUMNSTORE INDEX CCI ON dbo.Votes_columnstore
	WITH (DROP_EXISTING = ON);
GO


/* Are the row groups perfectly aligned on PostId now? */
sp_BlitzIndex @TableName = 'Votes_columnstore',
	@ShowColumnstoreOnly = 1;

/* Well, no: for *perfect* alignment, sadly,
you have to build your index with MAXDOP 1!
But I don't have time for that in the labs,
obviously.

Do we at least get decent segment elimination? */
SELECT VoteTypeId, YEAR(CreationDate) AS Yr, COUNT(*) AS VotesCast
  FROM dbo.Votes_columnstore
  WHERE PostId = 9033
  GROUP BY VoteTypeId, YEAR(CreationDate)
  ORDER BY VoteTypeId, YEAR(CreationDate);



/* WOOHOO! Victory!

That sucks - building the table once in order
to get segment elimination - but we're not done.

Make a note of the segment reads & skipped here:


Now let's simulate the ongoing daily insertions.
Every hour, we load between 5K and 500K new rows.

Let's put in a day's worth of new data.
This will take 15-45 seconds. */

INSERT INTO dbo.Votes_columnstore 
	(PostId, UserId, BountyAmount, VoteTypeId, CreationDate)
	SELECT TOP 5000 /* Small load hour */
		ABS(CHECKSUM(NEWID()) % 10000000) AS PostId, 
		ABS(CHECKSUM(NEWID()) % 10000000) AS UserId, 
		ABS(CHECKSUM(NEWID()) % 100) AS BountyAmount, 
		ABS(CHECKSUM(NEWID()) % 10) AS VoteTypeId, 
		GETDATE() AS CreationDate
	FROM dbo.Votes; /* Could use any table here, just grabbing one with a bunch of rows */
GO 12

INSERT INTO dbo.Votes_columnstore 
	(PostId, UserId, BountyAmount, VoteTypeId, CreationDate)
	SELECT TOP 500000 /* Big load hour */
		ABS(CHECKSUM(NEWID()) % 10000000) AS PostId, 
		ABS(CHECKSUM(NEWID()) % 10000000) AS UserId, 
		ABS(CHECKSUM(NEWID()) % 100) AS BountyAmount, 
		ABS(CHECKSUM(NEWID()) % 10) AS VoteTypeId, 
		GETDATE() AS CreationDate
	FROM dbo.Votes; /* Could use any table here, just grabbing one with a bunch of rows */
GO 12


/* Are the newly inserted segments aligned on PostId? */
sp_BlitzIndex @TableName = 'Votes_columnstore',
	@ShowColumnstoreOnly = 1;

/* Of course not.

People can cast votes for any PostId at any time.

So now, do we get segment elimination on our analytical query? */
SELECT VoteTypeId, YEAR(CreationDate) AS Yr, COUNT(*) AS VotesCast
  FROM dbo.Votes_columnstore
  WHERE PostId = 9033
  GROUP BY VoteTypeId, YEAR(CreationDate)
  ORDER BY VoteTypeId, YEAR(CreationDate);

/* We read more segments (and the delta store),
but ... were any votes cast for this PostId this year?
Are there any results for this year?

If not, we wasted our time reading today's segments.

Every time we read data for ANY PostId,
we're going to be reading all of the row groups
that were added since the last time we rebuilt.

WE LOST OUR SEGMENT ELIMINATION IN JUST THE FIRST DAY.
Granted, we only lose it on newly added data, but
this is going to get progressively worse over time.
Newly added data is effectively unsorted: every
row group contains data from all over the place.

This right here is where columnstore indexes start
to become more challenging, and we're going to need
a better way to handle index maintenance.

There's no way I can afford to take production down
every time I need to rebuild a table, and this is
a small table for columnstore!

I talk a lot about how index maintenance on rowstore
index doesn't matter much, but it matters a LOT on
columnstore indexes.


What we learned in this module:

* Build a proof-of-concept with a small subset
  of your full-sized table first.

* Test your daily load patterns (including inserts,
  updates, deletes).

* After a few days of daily load patterns, make
  sure your queries still get the performance
  you want. If they don't - and here, ours won't -
  we may need a better way to rebuild our indexes, 
  and that's where partitioning comes in. That's next.
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