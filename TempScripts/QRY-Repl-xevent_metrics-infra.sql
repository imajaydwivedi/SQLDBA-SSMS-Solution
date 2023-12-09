use DBA
go

declare @start_time datetime = '2022-05-25 12:00:00.000'
declare @end_time datetime = '2022-05-25 12:20:00.000'

select top 10 *
from dbo.xevent_metrics rc
where rc.start_time between @start_time and @end_time
or rc.event_time between @start_time and @end_time
--order by cpu_time desc;
go

declare @start_time datetime = '2022-05-24 22:00:00.000'
declare @end_time datetime = '2022-05-24 23:00:00.000'

select left(sql_text,25) as sql_text_filtered, sum(cpu_time/1000000)/60 as cpu_time_minutes, 
		convert(numeric(20,2),sum(logical_reads)*8.0/1024/1024) as logical_reads_gb, convert(numeric(20,2),sum(logical_reads)*8.0/1024/count(*)) as logical_reads_mb_avg,
		sum(rc.duration_seconds)/60 as duration_minutes, sum(rc.duration_seconds)/count(*) as duration_seconds_avg
		,count(*) as counts , sum(cpu_time/1000000)/count(*) as cpu_time_seconds_avg
from dbo.xevent_metrics rc
where rc.start_time between @start_time and @end_time
or rc.event_time between @start_time and @end_time
group by left(sql_text,25)
order by cpu_time_minutes desc, logical_reads_gb desc, duration_minutes desc
go

use DBA
go

declare @start_time datetime = '2022-05-24 22:00:00.000'
declare @end_time datetime = '2022-05-24 23:00:00.000'

select *
from dbo.xevent_metrics rc
where rc.start_time between @start_time and @end_time
or rc.event_time between @start_time and @end_time
order by cpu_time desc;
go

declare @start_time datetime = '2022-05-24 22:00:00.000'
declare @end_time datetime = '2022-05-24 23:00:00.000'

select left(sql_text,27) as sql_text_filtered, sum(cpu_time/1000000)/60 as cpu_time_minutes, 
		convert(numeric(20,2),sum(logical_reads)*8.0/1024/1024) as logical_reads_gb, convert(numeric(20,2),sum(logical_reads)*8.0/1024/count(*)) as logical_reads_mb_avg,
		sum(rc.duration_seconds)/60 as duration_minutes, sum(rc.duration_seconds)/count(*) as duration_seconds_avg
		,count(*) as counts , sum(cpu_time/1000000)/count(*) as cpu_time_seconds_avg
from dbo.xevent_metrics rc
where rc.start_time between @start_time and @end_time
or rc.event_time between @start_time and @end_time
group by left(sql_text,27)
order by cpu_time_minutes desc, logical_reads_gb desc, duration_minutes desc
go

use DBA
go

declare @start_time datetime = '2022-05-25 12:00:00.000'
declare @end_time datetime = '2022-05-27 12:00:00.000'

select top 10 client_app_name, 
		[cpu_time_minutes] = sum(cpu_time/1000000)/60, 
		[logical_reads_gb] = convert(numeric(20,2),sum(logical_reads)*8.0/1024/1024), 
		[logical_reads_mb_avg] = convert(numeric(20,2),sum(logical_reads)*8.0/1024/count(*)),
		[duration_minutes] = sum(rc.duration_seconds)/60, 
		[duration_seconds_avg] = sum(rc.duration_seconds)/count(*),
		[counts] = count(*),
		[cpu_time_seconds_avg] = sum(cpu_time/1000000)/count(*)
from dbo.xevent_metrics rc
where (rc.start_time between @start_time and @end_time
or rc.event_time between @start_time and @end_time)
and rc.client_app_name like 'SQL Job = %'
group by client_app_name
order by [logical_reads_mb_avg] desc, cpu_time_minutes desc, duration_minutes desc
go