select * from sys.dm_os_sys_info as osi
select * from sys.databases d where d.name = 'tempdb'
select	default_domain() as [domain],
		[ip] = CONNECTIONPROPERTY('local_net_address'),
		[sql_instance] = serverproperty('MachineName'),
		[server_name] = serverproperty('ServerName'),
		[host_name] = SERVERPROPERTY('ComputerNamePhysicalNetBIOS'),
		[sql_version] = @@VERSION,
		[service_name_str] = servicename,
		[service_name] = case when @@servicename = 'MSSQLSERVER' then @@servicename else 'MSSQL$'+@@servicename end,
		[instance_name] = @@servicename,
		service_account,
		SERVERPROPERTY('Edition') AS Edition,
		SERVERPROPERTY('ProductVersion') AS ProductVersion,
		SERVERPROPERTY('ProductLevel') AS ProductLevel
		--,instant_file_initialization_enabled
		--,*
from sys.dm_server_services 
where servicename like 'SQL Server (%)'
--or servicename like 'SQL Server Agent (%)'
go
