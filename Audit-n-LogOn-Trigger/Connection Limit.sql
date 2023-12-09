-- Commands to Run on SQL Server (Each Monitored Instance)

USE [master]
GO
-- Create Table: [dbo].[connection_limit_action_history]
CREATE TABLE [dbo].[connection_limit_action_history]
(
 program_name sysname,
 connection_count int,
 action_type varchar(20),
 action_date datetime DEFAULT(GETDATE()),
 CONSTRAINT pk_connection_limit_action_history
 PRIMARY KEY (program_name)
)
GO
GRANT SELECT ON [dbo].[connection_limit_action_history] TO [public]
GO
-- Create Table: [dbo].[connection_limit_threshold]
CREATE TABLE [dbo].[connection_limit_threshold]
(
 program_name sysname,
 limit smallint,
 CONSTRAINT pk_connection_limit_threshold
 PRIMARY KEY (program_name)
)
GO
GRANT SELECT ON [dbo].[connection_limit_threshold] TO [public]
GO
-- Create Table: [dbo].[connection_limit_threshold_history]
CREATE TABLE [dbo].[connection_limit_threshold_history]
(
  [program_name]     sysname    NOT NULL,
  [limit]     smallint    NULL,
  [collection_time]   datetime NOT NULL,
  [login_name]          varbinary(85) NULL,
  [session_id]               smallint   NULL,
  [operation]          varchar(1) NOT NULL,
  [id] numeric(16) IDENTITY NOT NULL
)
GO
GRANT SELECT ON [dbo].[connection_limit_threshold_history] TO [public]
GO
CREATE NONCLUSTERED INDEX [collection_time] on [dbo].[connection_limit_threshold_history] ([collection_time])
GO
-- Create Trigger: [dbo].[tgr_delete_connection_limit_threshold]
CREATE TRIGGER [dbo].[tgr_delete_connection_limit_threshold]
ON [dbo].[connection_limit_threshold]
FOR DELETE
AS
INSERT INTO [dbo].[connection_limit_threshold_history] (
     [program_name],
     [limit],
     [collection_time],
     [login_name],
     [session_id],
     [operation]
    )
SELECT
    deleted.[program_name],
    deleted.[limit],
    GETDATE(),
    SUSER_SID(),
    @@SPID,
    'D'
  FROM deleted
GO
-- Create Trigger: [dbo].[tgr_insert_connection_limit_threshold]
CREATE TRIGGER [dbo].[tgr_insert_connection_limit_threshold]
ON [dbo].[connection_limit_threshold]
FOR INSERT
AS
INSERT INTO [dbo].[connection_limit_threshold_history] (
     [program_name],
     [limit],
     [collection_time],
     [login_name],
     [session_id],
     [operation]
    )
SELECT
    inserted.[program_name],
    inserted.[limit],
    GETDATE(),
    SUSER_SID(),
    @@SPID,
    'I'
  FROM inserted
GO
-- Create Trigger: [dbo].[tgr_update_connection_limit_threshold]
CREATE TRIGGER [dbo].[tgr_update_connection_limit_threshold]
ON [dbo].[connection_limit_threshold]
FOR UPDATE
AS
INSERT INTO [dbo].[connection_limit_threshold_history] (
     [program_name],
     [limit],
     [collection_time],
     [login_name],
     [session_id],
     [operation]
    )
SELECT
    inserted.[program_name],
    inserted.[limit],
    GETDATE(),
    SUSER_SID(),
    @@SPID,
    'U'
  FROM inserted
GO
-- Insert Default Value
INSERT INTO [dbo].[connection_limit_threshold] VALUES ('default', 1000)
GO

-- =========================================================================================================
-- =========================================================================================================

-- Commands to Add to the Login Trigger (Each Monitored Instance)
-- Determine whether the login should be rejected due to excessive connections
IF EXISTS (SELECT OBJECT_ID('master.dbo.connection_limit_action_history'))
BEGIN
    IF EXISTS (SELECT 1 FROM master.dbo.connection_limit_action_history WHERE program_name = @app AND action_type = 'BLOCK')
    BEGIN
        DECLARE @default_limit int, @connection_count int, @connection_limit int;
        SELECT @default_limit = ISNULL(limit, 1000)
        FROM   [master].[dbo].[connection_limit_threshold]
        WHERE  program_name = 'default';
        SELECT    @connection_count = b.connection_count,
                @connection_limit = ISNULL(c.limit, @default_limit)
        FROM      [master].[dbo].[connection_limit_action_history] b
        LEFT JOIN [master].[dbo].[connection_limit_threshold] c ON b.program_name = c.program_name
        WHERE     [b].[action_type] = 'BLOCK';
        SET @message='Connection attempt by login ' + @login + ' from host ' + HOST_NAME() + ' with program '+ @app +' has been rejected due to breached concurrent connection limit (' + convert(varchar, @connection_count) + '>=' + convert(varchar, @connection_limit) + ').'
        RAISERROR (@message, 10, 1);
        ROLLBACK;
        RETURN;
    END
END

-- =========================================================================================================
-- =========================================================================================================
-- Steps to make entry into master..[connection_limit_action_history]
DECLARE @default_limit smallint, @warn_limit smallint = 100;
 
SELECT @default_limit = ISNULL(limit, 1000)
FROM   [master].[dbo].[connection_limit_threshold]
WHERE  program_name = 'default';
 
MERGE [master].[dbo].[connection_limit_action_history] AS target
USING (
       SELECT a.program_name, a.connection_count, CASE WHEN a.connection_count < ISNULL(dlc.limit, @default_limit) THEN 'WARN' ELSE 'BLOCK' END AS action_type
       FROM   (
               SELECT   des.program_name, COUNT(1) AS connection_count
               FROM     sys.dm_exec_sessions des
               WHERE    program_name IS NOT NULL
               GROUP BY des.program_name
              ) AS a
       LEFT JOIN [master].[dbo].[connection_limit_threshold] dlc ON a.program_name = dlc.program_name
       WHERE     a.connection_count >= ISNULL(dlc.limit, @default_limit) - @warn_limit
      ) AS source (program_name, connection_count, action_type) ON (target.program_name = source.program_name)
WHEN NOT MATCHED BY TARGET THEN INSERT (program_name, connection_count, action_type) VALUES (program_name, connection_count, action_type)
WHEN MATCHED AND (source.connection_count <> target.connection_count OR source.action_type <> target.action_type) THEN UPDATE SET target.connection_count = source.connection_count, target.action_type = source.action_type, action_date = GETDATE()
WHEN NOT MATCHED BY SOURCE THEN DELETE;
 
SELECT program_name, connection_count
FROM   [master].[dbo].[connection_limit_action_history]
WHERE  action_type = 'WARN';

-- =========================================================================================================
-- =========================================================================================================

USE [DBA]
GO

CREATE TABLE [dbo].[connection_session_details](
	[spid] [smallint] NULL,
	[host_process_id] [int] NULL,
	[login_time] [datetime] NULL,
	[host_name] [varchar](128) NULL,
	[client_net_address] [varchar](48) NULL,
	[program_name] [varchar](128) NULL,
	[client_version] [int] NULL,
	[login_name] [varchar](128) NULL,
	[client_interface_name] [varchar](32) NULL,
	[auth_scheme] [nvarchar](40) NULL,
	[collection_time] [datetime] NULL,
	[is_pooled] [bit] NULL
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[connection_session_details] ADD  CONSTRAINT [DF_collection_time]  DEFAULT (getdate()) FOR [collection_time]
GO

CREATE TABLE [dbo].[connection_session_details_summary](
	[summerization_context] [varchar](50) NULL,
	[context_parameter] [varchar](255) NULL,
	[collection_time] [datetime] NULL,
	[no_of_logins] [int] NULL
) ON [PRIMARY]
GO

CREATE VIEW [dbo].[connection_session_details]
AS
  SELECT *
  FROM   dbo.connection_session_details WITH (NOLOCK)
GO

-- =========================================================================================================
-- =========================================================================================================
-- Login Trigger
USE [master]
GO

CREATE TRIGGER [tgr_login_audit] ON ALL SERVER 
FOR 
LOGON 
AS 
SET XACT_ABORT OFF
/* This is the login trigger
 */ 
BEGIN
	-- Declare and Define Variables
    DECLARE @data xml, @ispooled bit, @cnyn bit, @ap bit, @aw bit, @login sysname, @message varchar(5000), @app nvarchar(128)
    SELECT @login = SUSER_NAME(), @app = APP_NAME(), @cnyn=CONVERT(bit, SESSIONPROPERTY('CONCAT_NULL_YIELDS_NULL')), @ap=CONVERT(bit, SESSIONPROPERTY('ANSI_PADDING')), @aw=CONVERT(bit, SESSIONPROPERTY('ANSI_WARNINGS'))

	DECLARE @engine_service_account varchar(500), @agent_service_account varchar(500);
	select @engine_service_account = service_account from sys.dm_server_services where servicename like ('SQL Server (%)')
	select @agent_service_account = service_account from sys.dm_server_services where servicename like ('SQL Server Agent (%)')

	-- Determine whether the login should be excluded from tracking in DBA.dbo.connection_session_details
    IF LOWER(@login) IN 
(@engine_service_account, @agent_service_account, 'sa','Contso\DBAs','Contso\adwivedi','Contso\SQLServices', 'Contso\SQLService', 'nt authority\system', LOWER(DEFAULT_DOMAIN()+'\'+CONVERT(nvarchar(128), SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))+'$')) 
        RETURN 
    IF @login LIKE N'%_sa' RETURN 
    IF ISNULL(DATABASEPROPERTYEX('DBA', 'Status'), 'N/A') <> 'ONLINE' RETURN 
   
	-- Determine whether the login should be rejected
	IF (
       (LEFT(LTRIM(@app), 1) = '-')
	    OR (@app ='' AND @login != 'some_exception_login_allowed_blank_app_name')
		OR (LOWER(@app) IN ('jtds', 'odbc'))
	    )
	BEGIN
		SET @message='Connection from '+ HOST_NAME() + ' using login '+ @login +' has been rejected as program_name is not registered'
		RAISERROR (@message, 10, 1)
		ROLLBACK
		RETURN
	END

	/*
    -- Disable SQL login from SSMS
    IF ((LOWER(@login) NOT LIKE N'%\%') AND (LOWER(@login) NOT LIKE N'%/hostbased') AND (@app like 'Microsoft SQL Server Management%'))
    BEGIN
      SET @message = 'Connections from application ' + @app + ' are not allowed for SQL Logins.'
      RAISERROR (@message, 10, 1)
      ROLLBACK
      RETURN
	END
	*/

	-- Reject connections for program_name above threshold limit defined in master.dbo.connection_limit_threshold
	IF (EXISTS (SELECT OBJECT_ID('master.dbo.connection_limit_threshold')) AND (CONVERT(varchar(128), SERVERPROPERTY('ServerName')) NOT LIKE '%\DRDS%'))
	BEGIN
	  DECLARE @connection_limit smallint,
			  @connection_count smallint;
	   SELECT @connection_limit = limit
		 FROM master.dbo.connection_limit_threshold WITH (NOLOCK)
		WHERE program_name = @app;
	  IF (@connection_limit IS NULL)
	  BEGIN
		SELECT @connection_limit = limit
		  FROM master.dbo.connection_limit_threshold WITH (NOLOCK)
		 WHERE program_name = 'default';
	  END;
	  SELECT @connection_count = COUNT(1)
		FROM sys.dm_exec_sessions WITH (NOLOCK)
	   WHERE program_name = @app;
	  IF (@connection_count > @connection_limit)
	  BEGIN
		SET @message='Connection attempt by login ' + @login + ' from host ' + HOST_NAME() + ' with program '+ @app +' has been rejected due to breached concurrent connection limit (' + convert(varchar, @connection_count) + '>=' + convert(varchar, @connection_limit) + ').';
		RAISERROR (@message, 10, 1);
		ROLLBACK;
		RETURN;
	  END;
	END;

	-- Determine whether the connection is pooled
    IF @cnyn=0	SET CONCAT_NULL_YIELDS_NULL ON 
    IF @ap=0	SET ANSI_PADDING ON  
    IF @aw=0	SET ANSI_WARNINGS ON
    SET @data = EVENTDATA()      
    SELECT @ispooled=@data.value('(/EVENT_INSTANCE/IsPooled)[1]', 'bit')
    IF @cnyn=0	SET CONCAT_NULL_YIELDS_NULL OFF  
    IF @ap=0	SET ANSI_PADDING OFF  
    IF @aw=0	SET ANSI_WARNINGS OFF  

	-- Try to log the information in DBA, but allow the login even if unsuccessful.
	BEGIN TRY
	--EXECUTE AS LOGIN = 'sqldbatools'
		INSERT INTO DBA.dbo.connection_session_details
		(
		spid,
		host_process_id,  
		login_time,     
		host_name,     
		client_net_address,     
		program_name,   
		client_version,   
		login_name,     
		client_interface_name,  
		auth_scheme,
		is_pooled
		)
		SELECT	@@SPID,  
				des.host_process_id,     
				des.login_time,     
				des.host_name,     
				dec.client_net_address,     
				des.program_name,  
				des.client_version,  
				--des.original_login_name,  
				@login,
				des.client_interface_name,  
				dec.auth_scheme,
				@ispooled 
		FROM	sys.dm_exec_sessions des
		JOIN	sys.dm_exec_connections dec ON des.session_id=dec.session_id AND des.session_id=@@SPID and dec.net_transport <> 'Session';
		REVERT;
	END TRY
	BEGIN CATCH
		--IF @@TRANCOUNT > 0 ROLLBACK;
		REVERT;
	END CATCH
END 



GO

ENABLE TRIGGER [tgr_login_audit] ON ALL SERVER
GO

-- =========================================================================================================
-- =========================================================================================================

/*
SELECT * FROM master.dbo.connection_limit_threshold;
SELECT * FROM master.dbo.[connection_limit_action_history];
--truncate table master.dbo.[connection_limit_action_history]


set nocount on;

if OBJECT_ID('tempdb..#connection_limit_blocked') is not null
	drop table #connection_limit_blocked;
;with T_Connections as (
	select [program_name], count(*) as connection_count
	from sys.dm_exec_sessions
	where [program_name] is not null
	group by [program_name]
)
,T_Blocked_Entry as (
	--insert  master.dbo.[connection_limit_action_history] ([program_name], connection_count, action_type, action_date)
	select [program_name], connection_count, coalesce(pl.limit, dl.limit) as limit,
			action_type = case when connection_count >= coalesce(pl.limit, dl.limit) then 'BLOCK'
								when connection_count >= coalesce(pl.limit, dl.limit)*0.8 then 'WARN'
								else NULL
								END, 
			action_date = GETDATE()
	--into #connection_limit_blocked
	from T_Connections as c
	outer apply (SELECT limit FROM master.dbo.connection_limit_threshold as l where l.[program_name] = c.[program_name] ) as pl
	outer apply (SELECT limit FROM master.dbo.connection_limit_threshold as d where d.[program_name] = 'default') as dl
)
select	*
into #connection_limit_blocked
from T_Blocked_Entry
where action_type is not null



-- insert new program
insert master.dbo.[connection_limit_action_history] ([program_name], connection_count, action_type, action_date)
select [program_name], connection_count, action_type, action_date
from #connection_limit_blocked as d
where d.action_type is not null
	and not exists (select * from master.dbo.[connection_limit_action_history] as b where b.[program_name] = d.[program_name])

-- update existing program
select d.[program_name], d.connection_count, d.action_type, d.action_date
from #connection_limit_blocked as d
join master.dbo.[connection_limit_action_history] as b 
	on b.[program_name] = d.[program_name]
where b.action_type <> d.action_type
or b.connection_count <> d.connection_count


EXEC sp_WhoIsActive


INSERT master.dbo.connection_limit_threshold
SELECT [program_name] = 'sql-server-load-generator.py'
			 ,[limit] = 30
			 ,[reference] = 'testing-connection-limit';

UPDATE master.dbo.connection_limit_threshold
SET limit = 20
WHERE [program_name] = 'sql-server-load-generator.py'
*/