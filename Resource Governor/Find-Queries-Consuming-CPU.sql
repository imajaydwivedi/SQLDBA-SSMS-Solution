USE [master]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* Create pools for the groups of users you want to track: */
CREATE RESOURCE POOL pool_WebSite;
CREATE RESOURCE POOL pool_Accounting;
CREATE RESOURCE POOL pool_ReportingUsers;
CREATE RESOURCE POOL pool_IPFreely;
CREATE RESOURCE POOL pool_Ajay;
CREATE RESOURCE POOL pool_SQLServiceAccount;
GO

CREATE WORKLOAD GROUP wg_WebSite USING [pool_WebSite];
CREATE WORKLOAD GROUP wg_Accounting USING [pool_Accounting];
CREATE WORKLOAD GROUP wg_ReportingUsers USING [pool_ReportingUsers];
CREATE WORKLOAD GROUP wg_IPFreely USING [pool_IPFreely];
CREATE WORKLOAD GROUP wg_Ajay USING [pool_Ajay];
CREATE WORKLOAD GROUP wg_SQLServiceAccount USING [pool_SQLServiceAccount];
GO

select SYSTEM_USER, suser_name()

/* For the purposes of my demo, I'm going to create
a few SQL logins that I'm going to classify into
different groups. You won't need to do this, since
your server already has logins. */
CREATE LOGIN [WebSiteApp] WITH PASSWORD=N'Passw0rd!', 
DEFAULT_DATABASE=[StackOverflow], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO
ALTER SERVER ROLE [sysadmin] ADD MEMBER [WebSiteApp]
GO

CREATE LOGIN [AccountingApp] WITH PASSWORD=N'Passw0rd!', 
DEFAULT_DATABASE=[StackOverflow], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO
ALTER SERVER ROLE [sysadmin] ADD MEMBER [AccountingApp]
GO

CREATE LOGIN [IPFreely] WITH PASSWORD=N'Passw0rd!', 
DEFAULT_DATABASE=[StackOverflow], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO
ALTER SERVER ROLE [sysadmin] ADD MEMBER [IPFreely]
GO


/* On login, this function will run and put people
into different groups based on who they are. */

CREATE OR ALTER FUNCTION [dbo].[ResourceGovernorClassifier]() 
RETURNS sysname 
WITH SCHEMABINDING
AS
BEGIN
	-- Define the return sysname variable for the function
	DECLARE @grp_name AS sysname;
	DECLARE @login AS sysname;
	SET @login = SUSER_NAME();

	SELECT @grp_name = CASE WHEN @login = 'WebSiteApp' THEN 'wg_WebSite'
							WHEN @login = 'AccountingApp' THEN 'wg_Accounting'
							WHEN @login LIKE 'Report%' THEN 'wg_ReportingUsers'
							WHEN @login = 'IPFreely' THEN 'wg_IPFreely'
							WHEN @login = 'MSI\ajayd' THEN 'wg_Ajay'
							WHEN @login = 'NT Service\MSSQLSERVER' THEN 'wg_SQLServiceAccount'
							WHEN @login = 'NT Service\SQLSERVERAGENT' THEN 'wg_SQLServiceAccount'
							ELSE 'default' 
						END;

	RETURN @grp_name;
END
GO

/* Tell Resource Governor which function to use: */
ALTER RESOURCE GOVERNOR 
WITH ( CLASSIFIER_FUNCTION = dbo.[ResourceGovernorClassifier])
--WITH ( CLASSIFIER_FUNCTION = dbo.[ResourceGovernorClassifier_Latest])
GO

/* Make changes effective
ALTER RESOURCE GOVERNOR RECONFIGURE
GO
*/

/*
exec sp_WhoIsActive @get_plans = 1;
exec sp_BlitzWho @ExpertMode = 1;

select * from sys.dm_resource_governor_resource_pools;
select * from sys.dm_resource_governor_workload_groups;

-- Releases all unused cache entries from all caches
DBCC FREESYSTEMCACHE  ('ALL')
*/