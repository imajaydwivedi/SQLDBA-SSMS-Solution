-- Commands to Run on SQL Server (Each Monitored Instance)

USE [master]
GO

-- drop table [dbo].[connection_limit_config]
CREATE TABLE [dbo].[connection_limit_config]
(
	[login_name] sysname not null,
	[program_name] sysname not null,
	[host_name] sysname not null,
	[limit] smallint,
	[reference] varchar(255) null,
	constraint pk_connection_limit_threshold primary key ([login_name],[program_name],[host_name])
)
GO
GRANT SELECT ON [dbo].[connection_limit_config] TO [public]
GO

-- drop table [dbo].[connection_limit_threshold_history]
CREATE TABLE [dbo].[connection_limit_threshold_history]
(
	[id] int IDENTITY(1,1) NOT NULL,
	[login_name] sysname not null,
	[program_name] sysname    NOT NULL,
	[host_name] sysname not null,
	[limit] smallint    NULL,
	[collection_time] datetime2 NOT NULL,
	[changed_by] sysname not NULL,
	[change_type] varchar(1) NOT NULL,
	[reference] varchar(255) NULL,
	constraint pk_connection_limit_threshold_history primary key nonclustered ([collection_time], [login_name], [id])
)
GO
GRANT SELECT ON [dbo].[connection_limit_threshold_history] TO [public]
GO
--CREATE NONCLUSTERED INDEX [ix_collection_time_login_name] on [dbo].[connection_limit_threshold_history] ([collection_time],[login_name])
GO

-- drop trigger if exists [tgr_delete_connection_limit_threshold]
CREATE TRIGGER [dbo].[tgr_delete_connection_limit_threshold]
	ON [dbo].[connection_limit_config]
FOR DELETE
AS
	INSERT INTO [dbo].[connection_limit_threshold_history] 
	( [login_name], [program_name], [host_name], [limit], [reference], [collection_time], [changed_by], [change_type] )
	SELECT	deleted.[login_name],
			deleted.[program_name],
			deleted.[host_name],
			deleted.[limit],
			deleted.[reference],
			sysdatetime(),
			ORIGINAL_LOGIN(),
			'D'
	  FROM deleted
GO

-- drop trigger if exists [tgr_insert_connection_limit_threshold]
CREATE TRIGGER [dbo].[tgr_insert_connection_limit_threshold]
	ON [dbo].[connection_limit_config]
FOR INSERT
AS
	INSERT INTO [dbo].[connection_limit_threshold_history] 
	( [login_name], [program_name], [host_name], [limit], [reference], [collection_time], [changed_by], [change_type] )
	SELECT	inserted.[login_name],
			inserted.[program_name],
			inserted.[host_name],
			inserted.[limit],
			inserted.[reference],
			sysdatetime(),
			ORIGINAL_LOGIN(),
			'I'
	FROM inserted
GO

-- drop trigger if exists [tgr_update_connection_limit_threshold]
CREATE TRIGGER [dbo].[tgr_update_connection_limit_threshold]
	ON [dbo].[connection_limit_config]
FOR UPDATE
AS
INSERT INTO [dbo].[connection_limit_threshold_history] 
	( [login_name], [program_name], [host_name], [limit], [reference], [collection_time], [changed_by], [change_type] )
	SELECT	inserted.[login_name],
			inserted.[program_name],
			inserted.[host_name],
			deleted.[limit],
			deleted.[reference],
			sysdatetime(),
			ORIGINAL_LOGIN(),
			'U'
  FROM inserted full outer join deleted
	on inserted.login_name = deleted.login_name
	and inserted.program_name = deleted.program_name
	and inserted.host_name = deleted.host_name
GO

-- Insert Default Value
-- TRUNCATE TABLE [dbo].[connection_limit_config]
INSERT INTO [dbo].[connection_limit_config] 
([login_name], [program_name], [host_name], [limit])
--SELECT [login_name] = '*', [program_name] = '*', [host_name] = '*', [limit] = 250
--UNION ALL
SELECT [login_name] = 'grafana', [program_name] = '*', [host_name] = '*', [limit] = 20;

select * from [dbo].[connection_limit_config]
GO

-- =========================================================================================================
-- =========================================================================================================

USE [DBA]
GO

-- DROP TABLE [dbo].[connection_history]
CREATE TABLE [dbo].[connection_history]
(
	[collection_time] [datetime2] NOT NULL default (SYSDATETIME()),
	[session_id] [smallint] NOT NULL,
	[login_name] [varchar](128) NULL,
	[program_name] [varchar](128) NULL,
	[host_name] [varchar](128) NULL,
	[client_net_address] [varchar](48) NULL,
	[net_transport] [nvarchar](40) NULL,
	[auth_scheme] [nvarchar](40) NULL,
	[is_pooled] [bit] NULL,
	[is_rejected_pseudo] [bit] not null default 0,
	[reject_condition] varchar(1000) null 
) --on ps_dba([collection_time])
GO

create index ci_connection_history on [dbo].[connection_history] 
	([collection_time]) --on ps_dba([collection_time])
go

-- =========================================================================================================
--DISABLE Trigger [tgr_login_audit] ON ALL SERVER;  
--GO
-- =========================================================================================================
-- Login Trigger
USE [master]
GO

GRANT VIEW SERVER STATE TO [public]
GO

IF EXISTS (select 1 from sys.server_triggers where name = 'tgr_login_audit')
	DROP TRIGGER [tgr_login_audit] ON ALL SERVER
GO


CREATE TRIGGER [tgr_login_audit] ON ALL SERVER
--WITH EXECUTE AS 'sa'
FOR LOGON 
AS 
SET XACT_ABORT OFF
BEGIN
	-- Declare Variables
	declare @app_name sysname = APP_NAME();
	declare @login_name sysname = ORIGINAL_LOGIN();
	declare @host_name sysname = host_name();
	declare @data xml;
	declare @ispooled bit;
	DECLARE @connection_limit smallint;
	DECLARE @connection_count smallint;
	DECLARE @config_login_name sysname;
	DECLARE @config_program_name sysname;
	DECLARE @config_host_name sysname;
	DECLARE @message varchar(5000);

	declare @engine_service_account sysname;
	declare @agent_service_account sysname;

	select @engine_service_account = service_account from sys.dm_server_services where servicename like ('SQL Server (%)');
	select @agent_service_account = service_account from sys.dm_server_services where servicename like ('SQL Server Agent (%)');

	--select [@app_name] = @app_name, [@login_name] = @login_name, [@host_name] = @host_name,	[@engine_service_account] = @engine_service_account, [@agent_service_account] = @agent_service_account;

	-- Determine whether the login should be excluded from tracking
    IF LOWER(@login_name) IN (@engine_service_account, @agent_service_account, 'sa','lab\sqldba','.\sql','nt authority\system', LOWER(DEFAULT_DOMAIN()+'\'+CONVERT(nvarchar(128), SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))+'$')) 
        RETURN ;
    IF @login_name LIKE N'%_sa'
		RETURN;
    IF ISNULL(DATABASEPROPERTYEX('DBA', 'Status'), 'N/A') <> 'ONLINE'
		RETURN;
	--IF ConnectionProperty('net_transport') IN ('Named pipe','Shared memory')
	--	RETURN;

	-- Reject connections above threshold limit defined in master.dbo.connection_limit_config
	IF EXISTS (SELECT OBJECT_ID('master.dbo.connection_limit_config'))
	BEGIN
		-- Find specific limit with all 3 parameters match
		SELECT @connection_limit = limit, @config_login_name = [login_name], @config_program_name = [program_name], @config_host_name = [host_name]
		FROM master.dbo.connection_limit_config WITH (NOLOCK)
		WHERE [login_name] = @login_name
		and [program_name] = isnull(@app_name,'*')
		and [host_name] = @host_name;

		-- If no specific limit is defined, use default
		IF (@connection_limit IS NULL)
		BEGIN
			SELECT @connection_limit = limit, @config_login_name = [login_name], @config_program_name = [program_name], @config_host_name = [host_name]
			FROM (
					SELECT	TOP 1 
							(case when [login_name] = @login_name then 200 else 0 end) +
							(case when [login_name] = '*' then 5 else 0 end) +
							(case when [program_name] = isnull(@app_name,'*') then 100 else 0 end) +
							(case when [program_name] = '*' then 5 else 0 end) +
							(case when [host_name] = @host_name then 100 else 0 end) +
							(case when [host_name] = '*' then 5 else 0 end) as [score], *
					FROM master.dbo.connection_limit_config WITH (NOLOCK)
					WHERE ([login_name] = @login_name  or [login_name] = '*')
					and ([program_name] = isnull(@app_name,'*') or [program_name] = '*')
					and ([host_name] = @host_name or [host_name] = '*')
					order by [score] desc
			) t_limit;					
		END;

		if @config_login_name = '*' and @config_program_name = '*' and @config_host_name = '*'
			select @connection_count = count(1)
			from sys.dm_exec_sessions es
			where  es.login_name = @login_name
		else
			select @connection_count = count(1)
			from sys.dm_exec_sessions es
			where (es.login_name = @login_name or @login_name = '*')
			and (es.program_name = @config_program_name or @config_program_name = '*')
			and (es.host_name = @config_host_name or @config_host_name = '*');

	  IF (@connection_count > @connection_limit)
	  BEGIN
		SET @message='Connection attempt by { login || program } = {{ ' + @login_name+' || '+@app_name+' }}' + ' from host ' + @host_name +' has been rejected due to breached concurrent connection limit (' + convert(varchar, @connection_count) + '>=' + convert(varchar, @connection_limit) + ').';
<<<<<<< HEAD
		RAISERROR (@message, 10, 1);
=======
		--RAISERROR (@message, 16, 1) WITH LOG;
		PRINT @message;
>>>>>>> 7ffbd302172b0661bb2d861fa0d3341afa88739d
		ROLLBACK;
		--RETURN;
	  END;
	END;

	-- Try to log the information in DBA, but allow the login even if unsuccessful.
		-- Record only pseudo rejections
	IF (@connection_count > @connection_limit)
	BEGIN
		BEGIN TRY
			-- Determine whether the connection is pooled
			SET @data = EVENTDATA()
			SET @ispooled = @data.value('(/EVENT_INSTANCE/IsPooled)[1]', 'bit');

			INSERT INTO [DBA].[dbo].[connection_history]
			(session_id, login_name, [program_name], [host_name], client_net_address, [net_transport], auth_scheme, is_pooled, is_rejected_pseudo, reject_condition)
			SELECT	@@SPID,
					@login_name,
					@app_name,    
					@host_name,     
					CONVERT(nvarchar(40),CONNECTIONPROPERTY('client_net_address')),
					CONVERT(nvarchar(40),CONNECTIONPROPERTY('net_transport')),
					CONVERT(nvarchar(40),CONNECTIONPROPERTY('auth_scheme')),
					@ispooled,
					is_rejected_pseudo = case when @connection_count > @connection_limit then 1 else 0 end,
					reject_condition = case when @connection_count <= @connection_limit then null 
											else '{{ login || app_name || host_name }} ~ {{ '+
													@login_name+' || '+isnull(@app_name,'')+' || '+@host_name+' }} '+
													'~ {{ '+convert(varchar, @connection_count)+' > '+convert(varchar, @connection_limit)+' }}'
											end
		END TRY
		BEGIN CATCH
			RETURN
		END CATCH
	END
END
GO

ENABLE TRIGGER [tgr_login_audit] ON ALL SERVER
GO

-- =========================================================================================================
-- =========================================================================================================
