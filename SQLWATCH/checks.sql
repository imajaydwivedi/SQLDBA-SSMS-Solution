select avg(cntr_value_calculated) 
from dbo.vw_sqlwatch_report_fact_perf_os_performance_counters
where counter_name = 'Processor Time %'
and report_time > dateadd(minute,-5,getutcdate())

select *
from [dbo].[sqlwatch_config_check]

