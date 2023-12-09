--	https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-repltrans-transact-sql?view=sql-server-2017
--	https://docs.microsoft.com/en-us/sql/relational-databases/replication/monitor/programmatically-monitor-replication?view=sql-server-2017

USE DBA;
CREATE TABLE dbo.Replication_Qu_History(
       Subscriber_db varchar(50) NOT NULL,
       Records_In_Que numeric(18, 0) NULL,
       CatchUpTime numeric(18, 0) NULL,
       LogDate datetime NOT NULL,
 CONSTRAINT PK_EPR_Replication_Que_History PRIMARY KEY CLUSTERED 
(
       Subscriber_db ASC, LogDate DESC
)
)
GO

DECLARE @replTrans TABLE (xdesid varchar(100), xact_seqno varchar(100));
INSERT @replTrans
exec Galaxy..sp_repltrans;

-- Transactions_Waiting_For_LogReaderAgent
SELECT COUNT(*) AS Transactions_Waiting_For_LogReaderAgent FROM @replTrans;
/*
xdesid					xact_seqno
----------------------	----------------------
0x00460586002862630001	0x004605860028626E0001
0x00460586002862710001	0x004605860028627E0001
*/

declare @_dbID smallint;
select @_dbID = d.database_id from sys.databases as d where d.name = 'Facebook';
exec distribution..sp_browsereplcmds @publisher_database_id = @_dbID;

USE DISTRIBUTION
GO
EXEC sp_replmonitorsubscriptionpendingcmds  
		  @publisher = 'YourPublisherServer', -- Put publisher server name here
��		  @publisher_db = 'Facebook', -- Put publisher database name here
��		  @publication ='FacebookPublication',� -- Put publication name here
��		  @subscriber ='YourSubscriberServer', -- Put subscriber server name here
��		  @subscriber_db ='Facebook', -- Put subscriber database name here
��		  @subscription_type ='1' -- 0 = push and 1 = pull

