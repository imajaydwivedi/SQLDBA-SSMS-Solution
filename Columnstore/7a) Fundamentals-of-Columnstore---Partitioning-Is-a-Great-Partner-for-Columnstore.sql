/*
Fundamentals of Columnstore: Partitioning Is a Great Partner for Columnstore
Part 1: Building the Partitioned Columnstore Table

v1.0 - 2020-10-17
https://www.BrentOzar.com/go/columnfund


This demo requires:
* SQL Server 2016 SP1 or newer
* Stack Overflow database 2018-06 version: https://www.BrentOzar.com/go/querystack

This first RAISERROR is just to make sure you don't accidentally hit F5 and
run the entire script. You don't need to run this:
*/
USE StackOverflow;
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 130;
GO


/* Create a numbers table with 1M rows: */
DROP TABLE IF EXISTS dbo.Numbers;
GO
CREATE TABLE Numbers (Number  int  not null PRIMARY KEY CLUSTERED);
;WITH
  Pass0 as (select 1 as C union all select 1), --2 rows
  Pass1 as (select 1 as C from Pass0 as A, Pass0 as B),--4 rows
  Pass2 as (select 1 as C from Pass1 as A, Pass1 as B),--16 rows
  Pass3 as (select 1 as C from Pass2 as A, Pass2 as B),--256 rows
  Pass4 as (select 1 as C from Pass3 as A, Pass3 as B),--65536 rows
  Pass5 as (select 1 as C from Pass4 as A, Pass4 as B),--Bigint
  Tally as (select row_number() over(order by C) as Number from Pass5)
INSERT dbo.Numbers
        (Number)
    SELECT Number
        FROM Tally
        WHERE Number <= 1000000;
GO

/* Create date partition function by month since Stack Overflow's origin,
modified from Microsoft Books Online: 
https://docs.microsoft.com/en-us/sql/t-sql/statements/create-partition-function-transact-sql?view=sql-server-ver15#BKMK_examples

DROP PARTITION SCHEME [DatePartitionScheme];
DROP PARTITION FUNCTION [DatePartitionFunction];
*/
DECLARE @DatePartitionFunction nvarchar(max) = 
    N'CREATE PARTITION FUNCTION DatePartitionFunction (datetime) 
    AS RANGE RIGHT FOR VALUES (';  
DECLARE @i datetime = '2008-06-01';
WHILE @i <= GETDATE()
BEGIN  
SET @DatePartitionFunction += '''' + CAST(@i as nvarchar(20)) + '''' + N', ';  
SET @i = DATEADD(MONTH, 3, @i);  
END  
SET @DatePartitionFunction += '''' + CAST(@i as nvarchar(20))+ '''' + N');';  
EXEC sp_executesql @DatePartitionFunction;  
GO  

/* Create matching partition scheme, but put everything in Primary: */
CREATE PARTITION SCHEME DatePartitionScheme  
AS PARTITION DatePartitionFunction  
ALL TO ( [PRIMARY] ); 
GO


DROP TABLE IF EXISTS [dbo].[Votes_columnstore_partitioned];
GO
CREATE TABLE [dbo].[Votes_columnstore_partitioned](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[PostId] [int] NOT NULL,
	[UserId] [int] NULL,
	[BountyAmount] [int] NULL,
	[VoteTypeId] [int] NOT NULL,
	[CreationDate] [datetime] NOT NULL
)
GO
/* For staging purposes, cluster on PostId.
This isn't a columnstore index, but I'm naming
it CCI because I'm going to replace it shortly. */
CREATE CLUSTERED INDEX CCI ON 
	dbo.Votes_columnstore_partitioned (PostId)
	ON DatePartitionScheme(CreationDate);
GO

SET IDENTITY_INSERT dbo.[Votes_columnstore_partitioned] ON;
GO
INSERT INTO dbo.[Votes_columnstore_partitioned] 
	(Id, PostId, UserId, BountyAmount, VoteTypeId, CreationDate)
	SELECT Id, PostId, UserId, BountyAmount, VoteTypeId, CreationDate
	FROM dbo.Votes;
GO
SET IDENTITY_INSERT dbo.[Votes_columnstore_partitioned] OFF;
GO

/* Switch to a clustered columnstore index. */
CREATE CLUSTERED COLUMNSTORE INDEX CCI
	ON dbo.Votes_columnstore_partitioned
	WITH (DROP_EXISTING = ON, MAXDOP = 1)
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