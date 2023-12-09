set nocount on;
go

select *
from master.dbo.connection_limit_config
go

declare @login_name sysname = 'grafana'--suser_name();
declare @app_name sysname = 'dbatools-test';
declare @host_name sysname = host_name();

select [@login_name] = @login_name, [@app_name] = @app_name, [@host_name] = @host_name;

--insert master.dbo.connection_limit_config (login_name, program_name, host_name, limit)
----select @login_name, @app_name, @host_name, 20
--select 'grafana','*','*',20
--update master.dbo.connection_limit_config set limit = 15 where login_name = 'grafana'

DECLARE @connection_limit smallint,
		@connection_count smallint;
DECLARE @config_login_name sysname;
DECLARE @config_program_name sysname;
DECLARE @config_host_name sysname;

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

select [@connection_limit] = @connection_limit, [@config_login_name] = @config_login_name, [@config_program_name] = @config_program_name, [@config_host_name] = @config_host_name;


if @config_login_name = '*' and @config_program_name = '*' and @config_host_name = '*'
	select [@connection_count] = count(1)
	from sys.dm_exec_sessions es
	where  es.login_name = @login_name
else
	select [@connection_count] = count(1)
	from sys.dm_exec_sessions es
	where (es.login_name = @login_name or @login_name = '*')
	and (es.program_name = @config_program_name or @config_program_name = '*')
	and (es.host_name = @config_host_name or @config_host_name = '*');

