use SQLWATCH;

CREATE SCHEMA [bkp] AUTHORIZATION [dbo];
CREATE SCHEMA [dbg] AUTHORIZATION [dbo];

select *
--into bkp.sqlwatch_config_action
from dbo.sqlwatch_config_action;

select *
from [dbo].[sqlwatch_meta_action_queue];

/*
update ca
set action_exec = 'exec msdb.dbo.sp_send_dbmail @recipients = ''sqlagentservice@gmail.com'',  @subject = ''{SUBJECT}'',  @body = ''{BODY}'',  @profile_name=''gmail'''
--select *
from dbo.sqlwatch_config_action ca
where action_id in (-2);

update ca
set action_exec = 'exec msdb.dbo.sp_send_dbmail @recipients = ''sqlagentservice@gmail.com'',  @subject = ''{SUBJECT}'',  @body = ''{BODY}'',  @profile_name=''gmail'',  @body_format = ''HTML'''
--select *
from dbo.sqlwatch_config_action ca
where action_id in (-1);

update ca
set action_enabled = 1
--select *
from dbo.sqlwatch_config_action ca
where action_id in (-2,-1);

update cc
set check_query = 'select @output=isnull(max(datediff(minute,backup_finish_date,getdate())),999)  from sys.databases d  left join msdb.dbo.backupset bs   on bs.database_name = d.name   and bs.type = ''L''  where d.recovery_model_desc <> ''SIMPLE''  and d.name not in (''tempdb'')'
--select * 
from dbo.sqlwatch_config_check as cc
where cc.check_id in (-17);


update o
set action_enabled = 0
from dbo.sqlwatch_config_action o
	,bkp.sqlwatch_config_action b
where b.action_id = o.action_id
	and b.action_enabled <> o.action_enabled
and o.action_id in (-16,-6,-5,-4,-3)
*/


-- Add Page Life Expectancy
INSERT [SQLWATCH].[dbo].[sqlwatch_config_performance_counters]
(object_name, counter_name, instance_name, base_counter_name, collect)
SELECT 'SQLServer:Buffer Manager' as object_name, 'Page life expectancy' as counter_name, '' as instance_name, null as base_counter_name, 1 as collect
