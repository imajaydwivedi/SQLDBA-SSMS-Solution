/*
Fundamentals of Columnstore: Partitioning Is a Great Partner for Columnstore
Part 2: Querying, Loading, and Updating

v1.1 - 2021-11-08
https://www.BrentOzar.com/go/columnfund


This demo requires:
* SQL Server 2016 SP1 or newer
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


/* In the setup script, we took a copy of the Votes
table, and loaded it into a partitioned columnstore.

Check out the row groups. Which column is going to
get segment elimination? */
sp_BlitzIndex @TableName = 'Votes_columnstore_partitioned',
	@ShowColumnstoreOnly = 1;
GO

/* We get:

* Partition elimination if we filter by CreationDate
* Segment elimination if we filter by PostId
* Both if we filter by both

Let's try filtering just by PostId.
Measure the segment elimination:
*/
SET STATISTICS IO ON; /* ACTUAL PLAN TOO */

SELECT VoteTypeId, YEAR(CreationDate) AS Yr, COUNT(*) AS VotesCast
  FROM dbo.Votes_columnstore_partitioned
  WHERE PostId = 9033
  GROUP BY VoteTypeId, YEAR(CreationDate)
  ORDER BY VoteTypeId, YEAR(CreationDate);
GO
/*	Lob logical reads: 
	Segments read:						*/


/* Then filter by date, too: */
SELECT VoteTypeId, YEAR(CreationDate) AS Yr, COUNT(*) AS VotesCast
  FROM dbo.Votes_columnstore_partitioned
  WHERE PostId = 9033
    AND CreationDate BETWEEN '2014-01-01' AND '2017-01-01'
  GROUP BY VoteTypeId, YEAR(CreationDate)
  ORDER BY VoteTypeId, YEAR(CreationDate);
GO
/*	Lob logical reads: 
	Segments read:						*/

/* To visualize partition elimination, we have to
open up the actual query plan, click on the
columnstore index scan, open the properties, and
read the Seek Properties.
*/




/* So far, so good.

But the problem we ran into in the last module
was when we added data over time. We will still
run into that problem as we add rows. Try it: */

INSERT INTO dbo.Votes_columnstore_partitioned
	(PostId, UserId, BountyAmount, VoteTypeId, CreationDate)
	SELECT TOP 5000 /* Small load hour */
		ABS(CHECKSUM(NEWID()) % 10000000) AS PostId, 
		ABS(CHECKSUM(NEWID()) % 10000000) AS UserId, 
		ABS(CHECKSUM(NEWID()) % 100) AS BountyAmount, 
		ABS(CHECKSUM(NEWID()) % 10) AS VoteTypeId, 
		GETDATE() AS CreationDate
	FROM dbo.Votes; /* Could use any table here, just grabbing one with a bunch of rows */
GO 12

INSERT INTO dbo.Votes_columnstore_partitioned
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
sp_BlitzIndex @TableName = 'Votes_columnstore_partitioned',
	@ShowColumnstoreOnly = 1;
GO

/* 
Partition elimination by date: we still get this.

Segment elimination by PostId: we don't get this
for the newly added data.
*/
SELECT VoteTypeId, YEAR(CreationDate) AS Yr, COUNT(*) AS VotesCast
  FROM dbo.Votes_columnstore_partitioned
  WHERE PostId = 9033
    /* AND CreationDate BETWEEN '2014-01-01' AND '2017-01-01'     Try with/without this */
  GROUP BY VoteTypeId, YEAR(CreationDate)
  ORDER BY VoteTypeId, YEAR(CreationDate);
GO
/*	Lob logical reads: 
	Segments read:						*/


/*
This isn't a big deal yet, but it'll get bigger
as we load more data each day. 

The real problem with an unpartitioned table was
that when we rebuilt it, we shuffled all the data.
To get a clean build, we have to:

* Export all the data
* Sort it by the column we want segment elimination
* Create the clustered columnstore index with MAXDOP 1

That doesn't scale - BUT NOW WITH PARTITIONING, it can!

Because I only have to do this for 1 partition!
We just...have to figure out how to do that.

These index maintenance tools don't come close:
	* Maintenance plans
	* Ola Hallengren's index scripts

These columnstore-focused ones come close, but
they don't do segment alignment for partitioned
tables yet:
	* Niko Neugebauer's Columnstore Index Script Library:
	  https://github.com/NikoNeugebauer/CISL
	* Emanuele Meazzo's script does, but not with partitions:
	  https://tsql.tech/a-script-to-automatically-align-columnstore-indexes-to-enhance-segment-elimination-and-hence-performances/
	  https://github.com/EmanueleMeazzo/tsql.tech-Code-snippets/blob/master/Maintenance/Align%20Columnstore%20Index.sql

So as of 2020, this is still an exercise left for
the reader - something I recommend folks build
into an ETL process that happens when they close
a partition, or want to tune that partition.

Here, I'm going to do it with plain T-SQL:

Find the partition we want to work on:
*/
sp_BlitzIndex @TableName = 'Votes_columnstore_partitioned',
	@ShowColumnstoreOnly = 1;
GO

DROP TABLE IF EXISTS [dbo].[Votes_staging];
GO
CREATE TABLE [dbo].[Votes_staging](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[PostId] [int] NOT NULL,
	[UserId] [int] NULL,
	[BountyAmount] [int] NULL,
	[VoteTypeId] [int] NOT NULL,
	[CreationDate] [datetime] NOT NULL,
	INDEX CCI CLUSTERED COLUMNSTORE
)
GO
ALTER TABLE dbo.Votes_columnstore_partitioned
	SWITCH PARTITION 59 TO dbo.Votes_staging; /* SET THE PARTITION NUMBER */
GO

/* Now we have dbo.Votes_staging with the contents of partition 51: */
SELECT TOP 100 * FROM dbo.Votes_staging;
GO

/* But it isn't aligned by PostId: */
sp_BlitzIndex @TableName = 'Votes_staging',
	@ShowColumnstoreOnly = 1;
GO
/* We could just plain rebuild it, but it won't be aligned: */
ALTER TABLE dbo.Votes_staging REBUILD;
GO
/* So we have to:
* Put a clustered index on it by PostId, then
* Replace that with a clustered columnstore, then
* Switch it back into the real partitioned Votes table
*/
CREATE CLUSTERED INDEX CCI 
	ON dbo.Votes_staging(PostId)
	WITH (DROP_EXISTING = ON);
GO
CREATE CLUSTERED COLUMNSTORE INDEX CCI
	ON dbo.Votes_staging
	WITH (DROP_EXISTING = ON, MAXDOP = 1);
GO
/* Check the alignment: */
sp_BlitzIndex @TableName = 'Votes_staging',
	@ShowColumnstoreOnly = 1;
GO

/* Switch it back into the main table: */
ALTER TABLE dbo.Votes_staging
	SWITCH TO dbo.Votes_columnstore_partitioned PARTITION 59; /* SET THE PARTITION NUMBER */
GO
/* Ugh, that's why Niko and Emanuele haven't
implemented this as an automatic feature yet. */
DECLARE @StringToExecute NVARCHAR(MAX) = N'
ALTER TABLE dbo.Votes_staging
	WITH CHECK ADD CONSTRAINT CreationDateMinMax
	CHECK (CreationDate >= ''' + (SELECT TOP 1 CONVERT(NVARCHAR(50), CreationDate, 121) FROM dbo.Votes_Staging ORDER BY CreationDate ASC) + N'''
	AND CreationDate <= ''' + (SELECT TOP 1 CONVERT(NVARCHAR(50), CreationDate, 121) FROM dbo.Votes_Staging ORDER BY CreationDate DESC) + N''');';
PRINT @StringToExecute;
EXEC(@StringToExecute);

/* Now it'll switch in: */
ALTER TABLE dbo.Votes_staging
	SWITCH TO dbo.Votes_columnstore_partitioned PARTITION 59; /* SET THE PARTITION NUMBER */
GO


/* Check the big table's alignment: */
sp_BlitzIndex @TableName = 'Votes_columnstore_partitioned',
	@ShowColumnstoreOnly = 1;
GO



/*
What we learned in this module:

* If we want segment elimination to stick around
  as we add data over time, we either have to
  rebuild the entire table every time, OR
  implement partitioning + custom dynamic SQL.

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