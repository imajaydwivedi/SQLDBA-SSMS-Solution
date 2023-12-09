/*
	https://docs.microsoft.com/en-us/previous-versions/sql/sql-server-2008-r2/ms152757(v=sql.105)
	https://docs.microsoft.com/en-us/previous-versions/sql/sql-server-2008-r2/ms188734(v=sql.105)
*/

-- Verify Server Name 1st
SELECT @@SERVERNAME as srvName
GO

sp_dropdistributiondb 'distribution'

-- Step 01 - Script out Publication from Publication Server
	--	Replication > Local Publications > [PubDatabase]: PubName > Right Click > Generate Scripts..

-- Step 02 - Execute below query on Subscriber Server.
	-- This removes replication from subscriber database
USE <<SubscriberDatabase>>
EXEC sp_removedbreplication
GO

-- Step 03 - Delete publication from Publisher server
	--	Replication > Local Publications > [PubDatabase]: PubName > Right Click > Delete
	--	Execute below query to make sure publication is removed.
USE <<PublicationDatabase>>
EXEC sp_removedbreplication
GO

-- Step 04 - Make sure all the replication jobs get removed with above step
	-- Log Reader agent job on Distributor server
	-- Distribution agent job on Distributor(push)/Subscriber(pull) server

