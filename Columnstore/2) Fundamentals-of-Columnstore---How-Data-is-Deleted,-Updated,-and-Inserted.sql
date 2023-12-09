/*
Fundamentals of Columnstore: How Data is Deleted, Updated, and Inserted
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
USE StackOverflow;
GO


/* Turn on actual plans and: */
SET STATISTICS IO, TIME ON;
GO

/* 
Say everyone in Paris decided to delete their accounts. 
How long does it take on the rowstore table? */
DELETE dbo.Users
	WHERE Location = N'Paris, France';
GO
/* Note:

* Logical reads: 
* CPU time: 
* Elapsed time: 
* Memory grant: 


Now before we try the same thing in columnstore, look at our data again.
How will we find the row groups with people in Paris?
When we find them, what segments will we be updating?
*/
sp_BlitzIndex @TableName = 'Users_columnstore',
	@ShowColumnstoreOnly = 1;
GO



/* Delete in columnstore: */
DELETE dbo.Users_columnstore
	WHERE Location = N'Paris, France';

/* Note:

* Logical reads: 
* CPU time: 
* Elapsed time: 
* Memory grant: 




That's kinda awesome.

Now how about updates?
How long does it take for everyone in London to log in? */
UPDATE dbo.Users
	SET LastAccessDate = GETDATE()
	WHERE Location = N'London, United Kingdom';
GO

/* Note:

* Logical reads: 
* CPU time: 
* Elapsed time: 
* Memory grant: 


Now before we try the same thing in columnstore, look at our data again.
How will we find the row groups with people in London?
When we find them, what segments will we be updating?
*/
sp_BlitzIndex @TableName = 'Users_columnstore',
	@ShowColumnstoreOnly = 1;
GO


/* Run the update: */
UPDATE dbo.Users_columnstore
	SET LastAccessDate = GETDATE()
	WHERE Location = N'London, United Kingdom';
GO

/* Note:

* Logical reads: 
* CPU time: 
* Elapsed time: 
* Memory grant: 

Now, how is our data organized:
*/


sp_BlitzIndex @TableName = 'Users_columnstore',
	@ShowColumnstoreOnly = 1;
GO
/* Things to notice:

* Update performance was not good, and CPU-intensive
* The first 9 row groups have "deleted rows" - 
  but we didn't delete anything
* There's a new 10th row group (with the same # of 
  rows as the 9 have deleted)


We now have a mix of two kinds of objects:

* The columnstore table: 
  made up of row groups & column segments

* A delta store: a conventional rowstore-type table
  with changes from all of the row groups, and 
  eventually that needs to be turned into a columnstore.



How about inserts? Add another 1K rows to Users: */
INSERT INTO [dbo].[Users]([AboutMe], [Age], [CreationDate], [DisplayName], [DownVotes], 
	[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId])
SELECT TOP 1000 [AboutMe], [Age], [CreationDate], [DisplayName], [DownVotes], 
	[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId]
FROM dbo.Users;
GO



/* Then try columnstore: */
INSERT INTO [dbo].[Users_columnstore]([AboutMe], [Age], [CreationDate], [DisplayName], [DownVotes], 
	[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId])
SELECT TOP 1000 LEFT([AboutMe], 4000), [Age], [CreationDate], [DisplayName], [DownVotes], 
	[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId]
FROM dbo.Users;
GO


/* Nice and fast...but there's a catch.

Where did the data go:
*/
sp_BlitzIndex @TableName = 'Users_columnstore',
	@ShowColumnstoreOnly = 1;
GO



/* What if we add, say, 10K rows? */
INSERT INTO [dbo].[Users_columnstore]([AboutMe], [Age], [CreationDate], [DisplayName], [DownVotes], 
	[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId])
SELECT TOP 10000 LEFT([AboutMe], 4000), [Age], [CreationDate], [DisplayName], [DownVotes], 
	[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId]
FROM dbo.Users;
GO


/* Where did the data go: */
sp_BlitzIndex @TableName = 'Users_columnstore';
GO


/* How about 100K rows? */
INSERT INTO [dbo].[Users_columnstore]([AboutMe], [Age], [CreationDate], [DisplayName], [DownVotes], 
	[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId])
SELECT TOP 100000 LEFT([AboutMe], 4000), [Age], [CreationDate], [DisplayName], [DownVotes], 
	[EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId]
FROM dbo.Users;
GO




/* Add 10K-100K rows a few more times. 

* How many row groups do you end up with? 
* When you need to run a select, how will this affect your query?
* When you need to run an update, how will this affect your query?
*/



/* What we learned in this module:

* Deletes are still pretty quick, but deletes 
  don't get vacuumed out of the row group right 
  away. Something is going to need to clean that 
  up later. More on that in a while.

* Inserts are quick, but depending on the amount 
  of rows you're adding, the new rows may end up 
  in different places: delta stores, or row groups.

* Update performance isn't as good, but that makes
  sense if you think about data warehouses circa
  ten years ago: we didn't do updates then.

* Over time, inserts, updates, and deletes are 
  going to leave us with a mess that can affect
  SELECT query performance, so...let's look at that
  next before we figure out how index maintenance
  happens.

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