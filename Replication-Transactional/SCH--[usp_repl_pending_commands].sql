create procedure [dbo].[usp_repl_pending_commands]
  @Debug bit = 0
as

set nocount on

/*
Select * from [dbo].[LOG_TRANSACTIONAL_REPLICATION_UNDISTRIBUTED_COMMANDS]
*/

--Method 1: 
--Exec [sys].[sp_replmonitorsubscriptionpendingcmds] @publisher,@publisher_db,@publication,@subscriber,@publisher_db,@subscription_type
/*
Cannot use this method to easily log into a table due to Error: Cannot Nest Insert Into Exec calls - because Insert into Exec is already used in 
sp_replmonitorsubscriptionpendingcmds.
*/

--Method 2: 
/*
Can use this easily to log into a logging table.
*/

Declare @publication sysname
Declare @publisher sysname
Declare @publisher_id int
Declare @publisher_db sysname
Declare @subscriber_db sysname
Declare @subscription_type int = 0
Declare @subscriber_id int
Declare @subscriber sysname
Declare @agent_id int
Declare @lastrunts timestamp
Declare @xact_seqno varbinary(16)
Declare @avg_rate float
Declare @MaxID int
Declare @PriorMaxLogIDLogged int

Set @PriorMaxLogIDLogged = (Select Max(LogID)
from [dbo].[LOG_TRANSACTIONAL_REPLICATION_UNDISTRIBUTED_COMMANDS])

--SET @publication = 'xyz'

Declare @PubDetails Table (Publication sysname,
  ID Int Identity(1,1),
  Publisher sysname NULL,
  PublisherDB sysname,
  Subscriber sysname,
  SubscriberDB sysname)
/*
Insert into @PubDetails (Publication, Publisher, PublisherDB, Subscriber, SubscriberDB)
SELECT t1.publication,t5.srvname, t1.publisher_db, t6.srvname,t3.subscriber_db
FROM [distribution].[dbo].[MSpublications] t1 
INNER JOIN [distribution].[dbo].[MSdistribution_agents] t3 on t1.publication = t3.publication
--INNER JOIN [MSDB].[dbo].[MSagent_profiles] t4 on t3.profile_id = t4.profile_id
INNER JOIN master..sysservers t5 ON t1.publisher_id = t5.srvid
INNER JOIN master..sysservers t6 ON t3.subscriber_id = t6.srvid 
--WHERE t1.publication = @publication
ORDER BY t6.srvname asc
*/
Insert into @PubDetails
  (Publication, Publisher, PublisherDB, Subscriber, SubscriberDB)
SELECT t1.publication, t5.name as publisher, t1.publisher_db, t6.name as subscrber, t3.subscriber_db
FROM [distribution].[dbo].[MSpublications] t1
  INNER JOIN [distribution].[dbo].[MSdistribution_agents] t3 on t1.publication = t3.publication
  --INNER JOIN [MSDB].[dbo].[MSagent_profiles] t4 on t3.profile_id = t4.profile_id
  LEFT JOIN master.sys.servers t5 ON t1.publisher_id = t5.server_id
  LEFT JOIN master.sys.servers t6 ON t3.subscriber_id = t6.server_id
--WHERE t1.publication = @publication
WHERE t6.name is not null
ORDER BY t5.name asc
--Select * from @PubDetails

If Exists (Select 1
from @PubDetails) 
Begin
  Set @MaxID = (Select Max(ID)
  from @PubDetails)
End

TRUNCATE TABLE [dbo].[LOG_TRANSACTIONAL_REPLICATION_UNDISTRIBUTED_COMMANDS]

While @MaxID > 0
Begin

  Set @publisher = (Select top 1
    Publisher
  from @PubDetails
  where ID = @MaxID)
  Set @publisher_db = (Select top 1
    PublisherDB
  from @PubDetails
  where ID = @MaxID)
  SET @publication = (Select top 1
    Publication
  from @PubDetails
  where ID = @MaxID)
  Set @subscriber_db = (Select top 1
    SubscriberDB
  from @PubDetails
  where ID = @MaxID)

  Set @subscriber = (Select top 1
    Subscriber
  from @PubDetails
  where ID = @MaxID)
  select @publisher_id = server_id
  from sys.servers
  where upper(name) = upper(@publisher)
  select @subscriber_id= server_id
  from sys.servers
  where upper(name) = upper(@subscriber)
  select @agent_id=id
  from distribution.dbo.MSdistribution_agents
  where publisher_id = @publisher_id and publisher_db = @publisher_db and publication in (@publication, 'ALL')
    and subscriber_id = @subscriber_id and subscriber_db = @subscriber_db and subscription_type = @subscription_type
  select @lastrunts = max(timestamp)
  from distribution.dbo.MSdistribution_history
  where agent_id = @agent_id
  select @xact_seqno = xact_seqno, @avg_rate = delivery_rate
  from distribution.dbo.MSdistribution_history
  where agent_id = @agent_id and timestamp = @lastrunts
  select @avg_rate = isnull(avg(delivery_rate),0.0)
  from distribution.dbo.MSdistribution_history
  where agent_id = @agent_id

  --Select @subscriber, @publisher_id, @subscriber_id, @agent_id, @lastrunts, @xact_seqno, @avg_rate

  Declare @countab Table (pendingcmdcount int)
  Insert into @countab
    (pendingcmdcount)
  Exec distribution.sys.sp_MSget_repl_commands @agent_id = @agent_id,@last_xact_seqno = @xact_seqno,@get_count = 2,@compatibility_level = 9000000

  --Select * from @countab

  Insert into [dbo].[LOG_TRANSACTIONAL_REPLICATION_UNDISTRIBUTED_COMMANDS]
    ([PublisherDB],[Publication],[Subscriber],[PendingCMDCount],[EstimatedProcessTime_sec],[InsertedDate])
  Select @publisher_db as 'Publisher', @publication as 'Publication', @subscriber as 'Subscriber', pendingcmdcount, N'estimatedprocesstime' = case when (@avg_rate != 0.0) then cast((cast(pendingcmdcount as float) / @avg_rate) as int) else pendingcmdcount
  end, getdate
  () from @countab

  Delete from @PubDetails where ID = @MaxID
  Set @MaxID = (Select Max(ID)
  from @PubDetails)
  --Delete from @PubDetails where Subscriber = @subscriber
  Delete from @countab
End

Insert into [dbo].[LOG_TRANSACTIONAL_REPLICATION_UNDISTRIBUTED_COMMANDS_History]
  ([PublisherDB],[Publication],[Subscriber],[PendingCMDCount],[EstimatedProcessTime_sec],[InsertedDate])
Select [PublisherDB], [Publication], [Subscriber], [PendingCMDCount], [EstimatedProcessTime_sec], [InsertedDate]
from [LOG_TRANSACTIONAL_REPLICATION_UNDISTRIBUTED_COMMANDS]



If @Debug = 1
Begin
  Select *
  from [dbo].[LOG_TRANSACTIONAL_REPLICATION_UNDISTRIBUTED_COMMANDS]
--where LogID > @PriorMaxLogIDLogged
End


