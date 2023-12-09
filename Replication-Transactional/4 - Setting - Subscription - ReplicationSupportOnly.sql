-- At Publisher Server
	-- Creating a PUSH/PULL subscription with @sync_type = N'replication support only'
USE DBA;
EXEC sp_addsubscription 
	@publication = N'DBAReplSyncOnly', 
	@subscriber = N'MSI\SQL2019', 
	@destination_db = N'DBAReplSyncOnly', 
	@subscription_type = N'Push', -- Pull for pull subscription
	@article = N'all',
	--BEGIN Backup Params
	@sync_type = N'replication support only'
	--END Backup Params
GO

-- OR --

-- At Publisher Server
	-- Creating a PUSH/PULL subscription with @sync_type = N'automatic'. For Snapshot methodStep
USE DBA;
EXEC sp_addsubscription 
@publication = N'DBAReplSyncOnly', 
@subscriber = N'MSI\SQL2019', 
@destination_db = N'DBAReplSnapshotSync', 
@subscription_type = N'Push', -- Pull for pull subscription
@article = N'all',
--BEGIN Backup Params
@sync_type = N'automatic '
--END Backup Params
GO

--	At Subscriber
use [ContsoSQLInventory_Dev];
EXEC sp_addpullsubscription 
	@publisher = 'YourPublisherServerName\SQL2016', 
	@publication= 'DIMS_Dev'
go

-- Create distribution agent on Subscriber
USE [ContsoSQLInventory_Dev];
EXEC sp_addpullsubscription_agent
	@publisher =  N'YourPublisherServerName\SQL2016',
	--@publisher_db = 'ContsoSQLInventory',
	@publication = N'DIMS_Dev', 
	--@subscriber = N'YourPublisherServerName\SQL2016', 
	--@subscriber_db = N'ContsoSQLInventory_Dev', 
	--@job_login = N'SQLSKILLSDEMOs\Administrator', 
	--@job_password = 'Password;1', 
	@subscriber_security_mode = 1, 
	-- Autostart
	@frequency_type = 64, 
	@frequency_interval = 0, 
	@frequency_relative_interval = 0, 
	@frequency_recurrence_factor = 0, 
	@frequency_subday = 0, 
	@frequency_subday_interval = 0, 
	@active_start_time_of_day = 0, 
	@active_end_time_of_day = 235959, 
	@active_start_date = 20120215, 
	@active_end_date = 99991231;
GO

-- Check snapshot agent job
:CONNECT SQL2K12-SVR2
SELECT name
FROM distribution.dbo.MSsnapshot_agents;
GO


-- ** Let's kick off the snapshot agent job now **

-- When we created it there were no subscriptions waiting...
:CONNECT SQL2K12-SVR2
EXEC msdb.dbo.sp_start_job 
'SQL2K12-SVR1-Credit-Pub_Credit-7' -- CHANGE this name
GO

:CONNECT SQL2K12-SVR3

SELECT category_no, category_desc
FROM [CreditReporting].[dbo].[category];
GO

-- Test a row insert
:CONNECT SQL2K12-SVR1 
USE Credit;

INSERT [Credit].[dbo].[category]
(category_desc)
VALUES ('This is a Test Also');
GO

:CONNECT SQL2K12-SVR3

SELECT category_no, category_desc
FROM [CreditReporting].[dbo].[category];
GO
