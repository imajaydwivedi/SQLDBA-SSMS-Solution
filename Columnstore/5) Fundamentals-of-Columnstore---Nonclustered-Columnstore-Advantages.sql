/*
Fundamentals of Columnstore: Nonclustered Columnstore Advantages
v1.0 - 2020-10-17
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
DropIndexes @TableName = 'Users';
GO

/* The Users table isn't a good fit for 
clustered columnstore because:
 * It's small
 * We update it a lot

But what if we only use columnstore on the
columns that AREN'T updated, like:

 * Id
 * CreationDate
 * DisplayName (rarely updated)
 * Location (rarely updated)

That's where nonclustered columnstore indexes
come in: you can pick the columns to index. 

Note that I'm creating this index on top of the
Users table, not Users_columnstore: */
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI
  ON dbo.Users(Location, DisplayName, CreationDate, Id);
GO
/* And create a conventional rowstore one: */
CREATE INDEX Location_DisplayName_CreationDate_Id
  ON dbo.Users(Location, DisplayName, CreationDate, Id);
GO
/* Compare their sizes: */
sp_BlitzIndex @TableName = 'Users' ,@ShowColumnstoreOnly = 1

/* Run an analytical-style query on Location: */
SET STATISTICS TIME, IO ON;

SELECT Location, COUNT(*) AS UsersCreated
	FROM dbo.Users WITH (INDEX = NCCI)
	GROUP BY Location
	ORDER BY COUNT(*) DESC;
	
SELECT Location, COUNT(*) AS UsersCreated
	FROM dbo.Users WITH (INDEX = Location_DisplayName_CreationDate_Id)
	GROUP BY Location
	ORDER BY COUNT(*) DESC;
	

/* But that's kinda close because our nonclustered
index started with Location: */
CREATE INDEX Location_DisplayName_CreationDate_Id
  ON dbo.Users(Location, DisplayName, CreationDate, Id);
GO

/* What happens if we run analytics on a DIFFERENT
leading column? That's where columnstore shines:
where you can't predict what people are going to
filter or group by: */
SELECT YEAR(CreationDate) AS Yr, MONTH(CreationDate) AS Mo,
	COUNT(*) AS UsersCreated
	FROM dbo.Users WITH (INDEX = NCCI)
	GROUP BY YEAR(CreationDate), MONTH(CreationDate)
	ORDER BY YEAR(CreationDate), MONTH(CreationDate);
	
SELECT YEAR(CreationDate) AS Yr, MONTH(CreationDate) AS Mo,
	COUNT(*) AS UsersCreated
	FROM dbo.Users WITH (INDEX = Location_DisplayName_CreationDate_Id)
	GROUP BY YEAR(CreationDate), MONTH(CreationDate)
	ORDER BY YEAR(CreationDate), MONTH(CreationDate);

/* And then if someone does an update, and they're
not touching columns in the columnstore index,
it's fast: */
UPDATE dbo.Users
	SET LastAccessDate = GETDATE()
	WHERE Location = N'London, United Kingdom';

DELETE dbo.Users
	WHERE Location = N'Paris, France';


/* And it doesn't affect the columnstore row groups: 
no rows are deleted and no new delta stores are added. */
sp_BlitzIndex @TableName = 'Users' ,@ShowColumnstoreOnly = 1


/* What we learned in this module:

Nonclustered columnstore indexes:

* Are better for transactional (OLTP) tables
  that have inserts, updates, and deletes

* Let you pick which columns you want to index
  (but you don't have to worry about column order)

* Get you great compression ratios

* If you run analytical-style queries on those
  rarely-updated columns, they can help

* But honestly, Users still isn't a good fit:
  it's tiny, and we'd still have to deal with
  index maintenance as we insert/delete rows.

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