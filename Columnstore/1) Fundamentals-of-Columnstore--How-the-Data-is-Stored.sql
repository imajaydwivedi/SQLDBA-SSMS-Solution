/*
Fundamentals of Columnstore: How the Data is Stored
v1.2 - 2021-11-08
https://www.BrentOzar.com/go/columnfund


This demo requires:
* SQL Server 2016 or newer
* Stack Overflow database 2018-06 version: https://www.BrentOzar.com/go/querystack
* sp_BlitzIndex 2020-09-16 or newer

This first RAISERROR is just to make sure you don't accidentally hit F5 and
run the entire script. You don't need to run this:
*/
RAISERROR(N'Oops! No, don''t just hit F5. Run these demos one at a time.', 20, 1) WITH LOG;
GO
USE StackOverflow;
GO
/* Quick reminder of the Users table structure.
Run this in another window while the below query
creates the columnstore table. */
SELECT TOP 100 * FROM dbo.Users;
GO


/* Create a table with the same columns as Users: */
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
/* Load it with the original Users contents. Takes ~60 seconds. */
SET IDENTITY_INSERT dbo.Users_columnstore ON;
GO
INSERT INTO dbo.Users_columnstore([Id], [AboutMe], [Age], [CreationDate], [DisplayName], [DownVotes], 
		[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId])
	SELECT [Id], LEFT([AboutMe], 4000), [Age], [CreationDate], [DisplayName], [DownVotes], 
		[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId]
	FROM dbo.Users;
GO
SET IDENTITY_INSERT dbo.Users_columnstore OFF;
GO


/* Compare the sizes of the two tables: */
sp_BlitzIndex @TableName = 'Users';
sp_BlitzIndex @TableName = 'Users_columnstore';


/* One big benefit of columnstore is compression.

But hey, rowstore indexes can do compression too:
let's set that up on the clustered index and see
the size before/after: */
ALTER TABLE dbo.Users REBUILD WITH (DATA_COMPRESSION = PAGE);

/* How much better did it get? How do they compare now? */
sp_BlitzIndex @TableName = 'Users';
sp_BlitzIndex @TableName = 'Users_columnstore';


/* Things to discuss:

* Rowstore objects have:
	* A clustered index (all the columns)
	* Nonclustered indexes (usually multiple sets)

* Clustered columnstore has:
	* A clustered index, but...
	* It's really an index on every column
	* There are no "white pages": if you want to
	  reassemble a row, you're going to need to
	  build it yourself from all the nonclustered
	  indexes 

To see what I mean, I've visualized it as the last 
result set in sp_BlitzIndex when you run it for a 
table with a columnstore index: */
sp_BlitzIndex @TableName = 'Users_columnstore';
GO

/* You can also just show the columnstore info: */
sp_BlitzIndex @TableName = 'Users_columnstore',
	@ShowColumnstoreOnly = 1;
GO

17 row groups * 10 columns = 170

INSERT -> batches of 1 millions +
DELETE -> batch for entire 1 year. Say 12 years old data
UPDATE -> Never
SELECT -> 
facts -> DeNormalized tables. 20-200 columns.
		 Can't predict queries and columns of those queries
		 group by, entire years (big batches), max, min, top, avg
Table type -> Numeric data, repetitive





/* Things to discuss:

* Columnstore is like an index on every column,
  but it's also kinda partitioned into Row Groups.
  Look at just the first row group at first.

* Row Groups: up to about 1M rows. The grouping
  of the rows depends on how the source table was
  sorted at the time the columnstore index was
  created - in this case, by Id.

  When you create a columnstore index for the 
  first time (or rebuild it), the sort of the 
  original data is really important for query plans.
  More on that later.

* AboutMe = NVARCHAR(MAX), and this is where 
  dictionaries come in

* on_disk_size: different data types & distributions 
  get different sizes.
	* Age = all nulls, so size is tiny
	* Id = all populated unique numbers, so larger
	* CreationDate = all populated (nearly) unique 
	  dates, even larger

* If you only wanted to calculate formulas off 
  specific columns, you could skip reading larger 
  columns like CreationDate, LastAccessDate

* However, if you want to assemble a row from scratch, 
  like if you do SELECT *, then you're going to have 
  to assemble it from all of the other indexes.

* DownVotes - this isn't sorted. There's a huge 
  range of data in each partition.

* Reputation - same here - why such a big range?

Well, look at the people who have the first 100 Ids:
*/
SELECT TOP 100 Id, Age, DownVotes, Reputation FROM dbo.Users ORDER BY Id ASC;

SELECT TOP 100 Id, Age, DownVotes, Reputation FROM dbo.Users ORDER BY Id DESC;

/*
This is going to have a huge impact on:

* How queries find the data they're looking for
* Which row groups can be eliminated
* Which segments can be eliminated
* How we prepare to load data by organizing it first
* How we load data with parallelism
* How, when, and why we do index maintenance
* Why we might even want to combine this with partitioning

And as we cover this stuff today, you'll better understand the kinds of data
and query workloads where columnstore makes sense, and where it doesn't.

*/



/* If you want to learn about the underlying row groups & segments: */
SELECT * 
FROM sys.column_store_segments seg /* These are kinda like the indexes on each column */
WHERE segment_id = 0; /* More on this later, but it's really the row_group_id. */

/* Add the column metadata in: */
SELECT OBJECT_NAME(p.object_id) AS table_name, seg.column_id, c.name AS column_name,
	seg.has_nulls, seg.primary_dictionary_id, seg.secondary_dictionary_id,
	seg.min_data_id, seg.max_data_id, seg.on_disk_size, seg.row_count
	FROM sys.column_store_segments seg
	INNER JOIN sys.partitions p ON seg.partition_id = p.partition_id
	INNER JOIN sys.columns c ON p.object_id = c.object_id AND seg.column_id = c.column_id
	WHERE seg.segment_id = 0 /* More on this later */
	ORDER BY OBJECT_NAME(p.object_id), seg.column_id;


/* The table is also broken up into row groups: */
SELECT OBJECT_NAME(object_id), * 
	FROM sys.column_store_row_groups rg
	ORDER BY index_id, row_group_id;

/* Row groups are:

* Kinda like table partitioning, a feature that lets you break up a table into
  groups of rows based on a partitioning column
* Columnstore doesn't exactly let you pick the partitioning column
  (although you can influence it at load time, and we'll cover that later)
* Different numbers of total rows (more on why later)
* Different sizes (because each row can have a different size)


So think of the Users_columnstore table as a grid of:
*/
SELECT OBJECT_NAME(p.object_id) AS table_name, rg.row_group_id, rg.total_rows,
	seg.column_id, c.name AS column_name,
	seg.min_data_id, seg.max_data_id, seg.on_disk_size
	FROM sys.column_store_segments seg
	INNER JOIN sys.partitions p ON seg.partition_id = p.partition_id
	INNER JOIN sys.columns c ON p.object_id = c.object_id AND seg.column_id = c.column_id
	INNER JOIN sys.column_store_row_groups rg ON seg.segment_id = rg.row_group_id AND p.object_id = rg.object_id
	ORDER BY OBJECT_NAME(p.object_id), seg.column_id, rg.row_group_id;
GO






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