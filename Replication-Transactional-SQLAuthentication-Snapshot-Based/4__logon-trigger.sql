USE master;
GO

-- Drop the trigger if it already exists
IF EXISTS (SELECT * FROM sys.server_triggers WHERE name = 'TR_RestrictNonAdminLogins')
    DROP TRIGGER TR_RestrictNonAdminLogins ON ALL SERVER;
GO

-- Create the logon trigger
CREATE TRIGGER TR_RestrictNonAdminLogins
ON ALL SERVER
FOR LOGON
AS
BEGIN
    -- Specify the allowed service account
    declare @service_account_engine varchar(125);
	declare @service_account_agent varchar(125);
	declare @logged_user varchar(125) = ORIGINAL_LOGIN();
	declare @sql_admin_login varchar(125) = 'SqlRadar';
	declare @is_caller_sysadmin int = IS_SRVROLEMEMBER('SYSADMIN', @logged_user);
	declare @sqlmonitor_login varchar(125) = 'grafana';

	select @service_account_engine = service_account from sys.dm_server_services ss	where servicename like 'SQL Server (%)';
	select @service_account_agent = service_account	from sys.dm_server_services ss where servicename like 'SQL Server Agent (%)';

    IF	NOT (	@logged_user in (@service_account_engine, @service_account_agent, @sql_admin_login, 'sa', @sqlmonitor_login)
			or	@logged_user like 'bidba.%'
			or	@is_caller_sysadmin = 1
			)
    BEGIN
        -- Rollback the connection attempt
		RAISERROR('Connection being rejected by Logon Trigger [TR_RestrictNonAdminLogins].', 20, 1) WITH LOG;
        ROLLBACK;
    END
END;
GO

ENABLE TRIGGER TR_RestrictNonAdminLogins ON ALL SERVER;
go

--DISABLE TRIGGER TR_RestrictNonAdminLogins ON ALL SERVER;
--go

--DROP TRIGGER TR_RestrictNonAdminLogins ON ALL SERVER;
--go