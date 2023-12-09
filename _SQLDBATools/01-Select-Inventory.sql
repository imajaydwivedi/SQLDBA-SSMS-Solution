use DBA
go

select GETDATE() as srv_time, GETUTCDATE() as utc_time, *
from dbo.sdt_server_inventory
go

select DATEDIFF(minute,last_notified_date_utc,GETUTCDATE()) as last_notified_minutes, 
		[is_suppressed_valid] = case when state = 'Suppressed' and (GETUTCDATE() between a.suppress_start_date_utc and a.suppress_end_date_utc) then 1 else 0 end,
		*
--update a set [state] = 'Suppressed', suppress_start_date_utc = GETUTCDATE(), suppress_end_date_utc = DATEADD(minute,20,GETUTCDATE())
--update a set [state] = 'Suppressed', suppress_end_date_utc = DATEADD(minute,2,suppress_start_date_utc)
--delete a
from dbo.sdt_alert a with (nolock)
--where alert_key = 'Alert-SdtDiskSpace'
order by created_date_utc desc
-- truncate table dbo.sdt_alert
go

select *
from dbo.sdt_alert_rules ar
go

/*
insert dbo.sdt_alert_rules (alert_key, server_friendly_name, severity, alert_receiver, alert_receiver_name, reference_request)
select 'Alert-SdtDiskSpace','SqlProd1',NULL,'sqlagentservice@gmail.com','Ajay','Testing'
union all
select 'Alert-SdtDiskSpace','SqlDr1',NULL,'sqlagentservice@gmail.com','Ajay','Testing'
*/

/*
if object_id('tempdb..#sdt_alert_rules_by_server') is not null
	drop table #sdt_alert_rules_by_server;
if object_id('tempdb..#sdt_alert_rules_by_owner') is not null
	drop table #sdt_alert_rules_by_owner;

select ar.rule_id, ar.alert_key, ar.server_friendly_name, i.server_owner, ar.alert_receiver
into #sdt_alert_rules_by_server
from dbo.sdt_alert_rules ar left join dbo.sdt_server_inventory i on i.friendly_name = ar.server_friendly_name
where ar.alert_key = 'Alert-SdtDiskSpace'
and ar.server_friendly_name in ('SqlProd1','SqlDr1','SqlProd2','Sqldr2','SqlProd3','SqlDr3')

select ar.rule_id, ar.alert_key, ar.server_friendly_name, i.server_owner, ar.alert_receiver
into #sdt_alert_rules_by_owner
from dbo.sdt_server_inventory i left join dbo.sdt_alert_rules ar on i.server_owner = ar.server_owner
where ar.alert_key = 'Alert-SdtDiskSpace'
and i.friendly_name in ('SqlProd1','SqlDr1','SqlProd2','Sqldr2','SqlProd3','SqlDr3')

select *
from #sdt_alert_rules_by_server s

select *
from #sdt_alert_rules_by_owner o
*/

