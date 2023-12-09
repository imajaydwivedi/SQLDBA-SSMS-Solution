use DBA
GO

select server, friendly_name, sql_instance, ipv4, stability, server_owner, is_active, monitoring_enabled
-- update i set server = 'SqlDr-A.Lab.com'
from dbo.sdt_server_inventory i
--where i.friendly_name = 'SqlDr1'
