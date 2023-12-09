:CONNECT SQL2K12-SVR1 
USE [Credit];

-- Creating a PUSH subscription
EXEC sp_addsubscription 
@publication = N'Pub_Credit', 
@subscriber = N'sql2k12-svr3', 
@destination_db = N'CreditReporting', 
@subscription_type = N'Push', 
-- Regarding @sync_type:
-- "none" (deprecated) for sub that already has data and schema
-- "automatic" - means schema/data pushed to subscriber first
-- "replication support only" - assumes data/schema already exist but generates article procedures/triggers
-- "initialize with backup" - schema/data from backup of publication db
-- "initialize from lsn' for adding node to P2P topoplogy and assumes subscriber already has schema/data
@sync_type = N'automatic';
GO

-- Create distribution agent
:CONNECT SQL2K12-SVR1 
USE [Credit];
EXEC sp_addpushsubscription_agent 
	@publication = N'Pub_Credit', 
	@subscriber = N'sql2k12-svr3', 
	@subscriber_db = N'CreditReporting', 
	@job_login = N'SQLSKILLSDEMOs\Administrator', 
	@job_password = 'Password;1', 
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
