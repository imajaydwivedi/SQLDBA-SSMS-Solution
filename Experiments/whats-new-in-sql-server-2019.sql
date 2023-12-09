/* 
--	https://www.brentozar.com/sql/whats-new-in-sql-server-2019-100-demos/
What's New in SQL Server 2019: 100% Demos

Brent Ozar - v1.9 - 2019-11-21

Download the latest version free: https://BrentOzar.com/go/whatsnew
Open source with the MIT License. For full details, see the end of this file.

Requirements:
* SQL Server 2019
* Stack Overflow database of any size: https://BrentOzar.com/go/querystack

This first RAISERROR is just to make sure you don't accidentally hit F5 and
run the entire script. You don't need to run this:
*/
RAISERROR(N'Oops! No, don''t just hit F5. Run these demos one at a time.', 20, 1) WITH LOG;
GO


/* Demo setup: */
USE StackOverflow2013;
GO
DropIndexes;
GO
CREATE INDEX IX_Reputation ON dbo.Users(Reputation);
CREATE INDEX IX_Location ON dbo.Users(Location);
CREATE INDEX IX_OwnerUserId ON dbo.Posts(OwnerUserId) INCLUDE (Score, Title);
CREATE INDEX IX_PostId ON dbo.Comments(PostId);
ALTER DATABASE SCOPED CONFIGURATION SET LAST_QUERY_PLAN_STATS = ON;
SET STATISTICS IO, TIME ON;
GO





ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 140; /* 2017 */
GO
DECLARE @CoolCars TABLE (Make VARCHAR(30), Model VARCHAR(30));

INSERT INTO @CoolCars (Make, Model)
  VALUES ('Porsche', '911');

SELECT * FROM @CoolCars;
GO




DECLARE @CoolCars TABLE (Make VARCHAR(30), Model VARCHAR(30));

INSERT INTO @CoolCars (Make, Model)
  VALUES ('Porsche', '911'),
         ('Audi', 'RS5'),
		 ('Dodge', 'Hellcat'),
		 ('Chevrolet', 'Corvette'),
		 ('BMW', 'M5');

SELECT * FROM @CoolCars;
GO


/* Possible solutions in the past: change the code to add recompile hint, temp tables 





Or...just switch to 2019 compatibility level:
*/
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 150; /* 2019 */
GO
DECLARE @CoolCars TABLE (Make VARCHAR(30), Model VARCHAR(30));

INSERT INTO @CoolCars (Make, Model)
  VALUES ('Porsche', '911'),
         ('Audi', 'RS5'),
		 ('Dodge', 'Hellcat'),
		 ('Chevrolet', 'Corvette'),
		 ('BMW', 'M5');

SELECT * FROM @CoolCars;
GO









/* You probably still find stored procedures with table variables: */
CREATE OR ALTER PROC dbo.usp_PostsByUserLocation @Location NVARCHAR(40) AS
BEGIN
	DECLARE @UserList TABLE (Id INT);
	INSERT INTO @UserList (Id)
	  SELECT Id FROM dbo.Users WHERE Location LIKE @Location

    SELECT TOP 1000 p.Score, p.Id, p.Title, p.Body, p.Tags, uC.DisplayName, c.Text
        FROM @UserList u
        JOIN dbo.Posts p ON p.OwnerUserId = u.Id AND p.PostTypeId = 1
		LEFT OUTER JOIN dbo.Comments c ON p.Id = c.PostId
		LEFT OUTER JOIN dbo.Users uC ON c.UserId = uC.Id
        ORDER BY p.Score DESC, c.CreationDate;
END
GO



ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 140; /* 2017 */
GO
EXEC usp_PostsByUserLocation @Location = 'United States%';
GO
/* 
SQL Server 2017:
* Underestimates rows in the table variable, 
* Which leads to single-threaded processing and a low memory grant
* Which leads to tempdb spills 
*/

ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 150; /* 2019 */
GO
EXEC usp_PostsByUserLocation @Location = 'United States';
GO

/* 
SQL Server 2019 is quite a bit faster because:

* It accurately estimates rows for the table variable
* Memory grant is more accurate
* No tempdb spills


Before we go on, note:
* The memory grant: 
* The number of users: 
* The number of questions: 

Then try another location: 
*/
EXEC usp_PostsByUserLocation @Location = 'Boston, MA, USA';
GO


/* 
The good news: table variables get stats.

The bad news: now they're vulnerable to parameter sniffing.
*/







/*
SQL Server has a new tool to help: adaptive memory grants.
*/
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 140; /* 2017 */
GO
EXEC usp_PostsByUserLocation @Location = 'United States';
GO



/* And again: */
EXEC usp_PostsByUserLocation @Location = 'United States';
GO





ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 150; /* 2019 */
GO
EXEC usp_PostsByUserLocation @Location = 'United States';
GO
/* Try that a few times */



/* Try that a few times, then: */
EXEC usp_PostsByUserLocation @Location = 'Boston, MA, USA';
GO


/* Here comes our American friend again: */
EXEC usp_PostsByUserLocation @Location = 'United States';
GO


/* 
The good news: your memory grant will change, preventing spills and RESOURCE_SEMAPHORE.

The bad news:
* Your memory grant will drop, CAUSING spills
* It will flip back & forth, and then settle on a number which may not be good either
* This process restarts every time you rebuild an index, update stats, fail over, reboot

The great news:
* In many cases, it's still better than prior versions were!

*/







/* SQL Server 2019 has a new tool to help: the ability to see a query's last 
actual execution plan! It's turned on at the database level with this, which I
ran at the start of the demos:

ALTER DATABASE SCOPED CONFIGURATION SET LAST_QUERY_PLAN_STATS = ON;

In another window (to save the original actual plan), turn off actual plans: */
sp_BlitzCache;
GO

/* Or if you like working with the plan handles directly: */
SELECT * FROM sys.dm_exec_query_plan_stats(0x050005000AFEBC35F0BE92666B01000001000000000000000000000000000000000000000000000000000000);
GO
/* 
The good news: you can get the last "actual" plan for a query that ran recently.

The bad news:
* No wait stats
* No elapsed time
* No CPU metrics
* The memory grant is there, but it's wrong - it's for the NEXT execution

Still a fantastic starter for actual vs estimated rows, though.

It does have drawbacks that impact performance, so I'm going to turn it off for
the rest of the demos:
*/
ALTER DATABASE SCOPED CONFIGURATION SET LAST_QUERY_PLAN_STATS = OFF;
GO






/* Next SQL Server 2019 feature: inlined user-defined functions, aka Froid. 

Warm up the cache:
*/
SELECT COUNT(*) FROM dbo.Votes;
GO

CREATE OR ALTER FUNCTION dbo.GetVotesCount ( @UserId INT )
RETURNS BIGINT
    WITH RETURNS NULL ON NULL INPUT
AS
    BEGIN
        DECLARE @Count BIGINT;
        SELECT  @Count = COUNT_BIG(*)
        FROM    dbo.Votes
        WHERE   UserId = @UserId;
        RETURN @Count;
    END;
GO

/* Use it in a stored procedure: */
CREATE OR ALTER PROC dbo.usp_UsersByReputation @Reputation INT AS
    SELECT TOP 10 u.DisplayName, u.Location, u.WebsiteUrl, u.AboutMe, u.Id
        FROM dbo.Users u
        WHERE Reputation = @Reputation
		  AND dbo.GetVotesCount(u.Id) = 0; /* BAD IDEA */
GO



/* Go back to SQL Server 2017 and run it with ACTUAL PLANS on: */
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 140;
GO
DBCC FREEPROCCACHE;
GO
EXEC usp_UsersByReputation @Reputation = 2;
GO


/* 
Things to note:
* It takes a little while on my laptop.
* Both the plan and stats IO hide the impact. 
* The plan appears to be limited to a single core.

To see the truth, run this in another window without actual plans:
*/
sp_BlitzCache;
GO





/* Switch to 2019 and run it with ACTUAL PLANS on: */
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 150;
GO
DBCC FREEPROCCACHE;
GO
EXEC usp_UsersByReputation @Reputation = 2;
GO



/* May need to get the estimated plan in another window while this runs. ;-) */




DBCC FREEPROCCACHE;
GO
/* Just get the estimated plan, and note no parallelism: */
EXEC usp_UsersByReputation @Reputation = 2;
GO


/* And yet this query goes parallel: */
SELECT COUNT(*) FROM dbo.Users;
GO


/* 
The good news: SQL Server 2019 automatically inlines some kinds of functions

The bad news:
* But that doesn't mean your query will go faster
* Because it also changes the shape of the plan
* It doesn't mean your query will go parallel either
* Test, test, test
* You can still do way better by getting rid of the function yourself:
*/
CREATE OR ALTER PROC dbo.usp_UsersByReputation @Reputation INT AS
    SELECT TOP 10 u.DisplayName, u.Location, u.WebsiteUrl, u.AboutMe, u.Id
        FROM dbo.Users u
		LEFT OUTER JOIN dbo.Votes v ON u.Id = v.UserId
        WHERE Reputation = @Reputation
		  AND v.Id IS NULL;
GO


EXEC usp_UsersByReputation @Reputation = 2;
GO


/* Inline scalar functions can even crash your SQL Server:
https://dba.stackexchange.com/questions/253499/
https://sql-sasquatch.blogspot.com/2019/11/sql-server-2019-udf-inlining-oom-in.html
*/



/* Fine, forget functions. 

Next feature: adaptive joins on rowstore tables.

Take a stored procedure - no functions this time:
*/
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 150; /* SQL Server 2019 */
GO
CREATE OR ALTER PROC dbo.usp_UsersByReputation @Reputation INT AS
    SELECT TOP 100000 u.Id, p.Title, p.Score
        FROM dbo.Users u
        JOIN dbo.Posts p ON p.OwnerUserId = u.Id
        WHERE u.Reputation = @Reputation
        ORDER BY p.Score DESC;
GO

/* And run it: */
EXEC usp_UsersByReputation @Reputation = 1;
GO



/* Check out that adaptive join:
* Adaptive threshold in tooltip
* Over threshold: do an index scan
* Under: do a seek



Try another reputation, and it chooses the seek: */
EXEC usp_UsersByReputation @Reputation = 2;
GO

/* Try the big one: */
EXEC usp_UsersByReputation @Reputation = 1;
GO




/* Check the actual plan.
* Adaptive joins need memory
* That memory is affected by adaptive grants
* We ran it for a tiny reputation (2), then a big one (1) - it got a tiny grant

Try running it again, and it spills way less:
*/
EXEC usp_UsersByReputation @Reputation = 1;
GO

/* May need to do that a few times to stabilize */


/* But as soon as someone runs it for a tiny value again... */
EXEC usp_UsersByReputation @Reputation = 2;
GO

/* And then 1 runs, he's screwed again. */
EXEC usp_UsersByReputation @Reputation = 1;
GO


/* Moral of the story: parameter sniffing just got a LOT harder. 

Plus, check this out:
*/
DBCC FREEPROCCACHE;
GO
EXEC usp_UsersByReputation @Reputation = 1 WITH RECOMPILE; /* Gets an adaptive join */
EXEC usp_UsersByReputation @Reputation = 2 WITH RECOMPILE; /* Index seek on Users, no adaptive join, single threaded */
EXEC usp_UsersByReputation @Reputation = 3 WITH RECOMPILE; /* Index seek on Users, no adaptive join, parallel */



/*
The good news: SQL Server 2019 has more execution plan options.

The bad news: parameter sniffing just got harder to troubleshoot and fix, not easier.
*/










/* Next feature: batch mode on rowstore. Run this twice just to get a cached baseline, and note CPU time: */
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 140;
GO
SELECT YEAR(v.CreationDate) AS CreationYear, MONTH(v.CreationDate) AS CreationMonth,
    COUNT(*) AS VotesCount,
    AVG(BountyAmount * 1.0) AS AvgBounty
  FROM dbo.Votes v
  GROUP BY YEAR(v.CreationDate), MONTH(v.CreationDate)
  ORDER BY YEAR(v.CreationDate), MONTH(v.CreationDate)
GO


/* Then try in 2019: */
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 150;
GO
SELECT YEAR(v.CreationDate) AS CreationYear, MONTH(v.CreationDate) AS CreationMonth,
    COUNT(*) AS VotesCount,
    AVG(BountyAmount * 1.0) AS AvgBounty
  FROM dbo.Votes v
  GROUP BY YEAR(v.CreationDate), MONTH(v.CreationDate)
  ORDER BY YEAR(v.CreationDate), MONTH(v.CreationDate)
GO



/*
The good news: reporting-style queries with grouping, aggregates, etc are getting way faster.

The bad news: again, more query plan choices - some of which can go wrong.
*/



/* To make that even faster, we can create indexes.
Resumable index creation */
CREATE NONCLUSTERED INDEX IX_CreationDate_Includes on dbo.Votes (CreationDate) INCLUDE (PostId, UserId, BountyAmount, VoteTypeId) 
  WITH (ONLINE=ON, RESUMABLE=ON, MAX_DURATION=1);
GO

/* In another window: */
ALTER INDEX IX_CreationDate_Includes ON dbo.Votes PAUSE;

SELECT * FROM sys.index_resumable_operations;


ALTER INDEX IX_CreationDate_Includes ON dbo.Votes ABORT;
ALTER INDEX IX_CreationDate_Includes ON dbo.Votes RESUME;


/* But you have to be careful, because that's not the only way to pause an index creation.
Watch what happens when I cancel my own query:
*/
CREATE NONCLUSTERED INDEX IX_CreationDate_Includes on dbo.Votes (CreationDate) INCLUDE (PostId, UserId, BountyAmount, VoteTypeId) 
  WITH (ONLINE=ON, RESUMABLE=ON, MAX_DURATION=1);
GO


/* And same thing if I kill it.

And if there are any pending operations on the table, you can't do others:
*/
CREATE INDEX IX_UserId ON dbo.Votes(UserId);

/*
So moral of the story:
* Don't use RESUMABLE = ON unless you really want it
* If you want it, don't cancel your query unless you clean up after yourself
* Watch the contents of sys.index_resumable_operations

And whatever you do, don't do this.
This makes all index creations escalate automatically: 
*/
ALTER DATABASE SCOPED CONFIGURATION 
    SET ELEVATE_ONLINE = WHEN_SUPPORTED;
ALTER DATABASE SCOPED CONFIGURATION 
    SET ELEVATE_RESUMABLE = WHEN_SUPPORTED;
GO


/* So now, even if I don't ask for resumable, and I cancel my query: */
CREATE NONCLUSTERED INDEX IX_CreationDate_Includes on dbo.Votes (CreationDate) INCLUDE (PostId, UserId, BountyAmount, VoteTypeId) 
--  WITH (ONLINE=ON, RESUMABLE=ON, MAX_DURATION=1);

/* If I cancel my query, it's left behind as resumable: */
SELECT * FROM sys.index_resumable_operations;
GO





/* 
Speaking of canceling queries - you know what sucks? Rollbacks and failovers.


I'm going to set up an index to slow down my updates: 
*/
CREATE INDEX IX_Reputation_LastAccessDate ON dbo.Users(Reputation, LastAccessDate);
GO


/* Run a transaction that does a lot of work: */
BEGIN TRAN
UPDATE dbo.Users
  SET Reputation = 1000000,
      LastAccessDate = GETDATE();
GO


/* Oops! Forgot our WHERE clause! Gotta roll back. */
ROLLBACK
GO


ALTER DATABASE StackOverflow2013 SET ACCELERATED_DATABASE_RECOVERY = ON;
SELECT * FROM sys.databases;

/* Run a transaction that does a lot of work: */
BEGIN TRAN
UPDATE dbo.Users
  SET Reputation = 1000000,
      LastAccessDate = GETDATE();
GO

/* How much space is being used? */
SELECT TOP 100 * FROM sys.dm_tran_persistent_version_store_stats
SELECT TOP 100 * FROM sys.dm_tran_top_version_generators
SELECT TOP 100 * FROM sys.dm_tran_version_store
SELECT TOP 100 * FROM sys.dm_tran_version_store_space_usage

/* Clustered index */
SELECT * FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.Users'), 1, 0, 'DETAILED')

/* Nonclustered index */
SELECT * FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.Users'), 2, 0, 'DETAILED')


/* The big payoff: */
ROLLBACK;
GO





/*
SQL Server 2019 will help most of this code run faster:

* Table variables
* Scalar user-defined functions
* Reports with grouping, aggregate functions on tables without columnstore indexes
* Rollbacks & failovers

And these DBA jobs are easier:

* Seeing the "actual" plan for a recently-slow query
* Index creations
* Dealing with questions about rollbacks

But these DBA jobs are harder:

* Testing ALL of your code before you go live
* Dealing with parameter sniffing and unpredictable performance

Next step to learn more: BrentOzar.com/go/whatsnew
*/


/* 
MIT License

Copyright (c) 2019 Brent Ozar Unlimited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/