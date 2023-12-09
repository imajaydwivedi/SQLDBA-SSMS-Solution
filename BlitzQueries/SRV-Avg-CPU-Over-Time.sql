use DBA
go

DECLARE @From datetime = '2021-09-28 21:00:00.000'
DECLARE @To datetime = '2021-09-28 23:00:00.000'
DECLARE @NoOfDays int = 14;

-- Generate start_time/end_time for @NoOfDays
if object_id('tempdb..#event_time_table') is not null
	drop table #event_time_table;
with dates as (
	select @From as start_time, @To as end_time, @NoOfDays as no_of_day
	union all
	select dateadd(day,-(@NoOfDays-(no_of_day-1)),@From) as start_time, dateadd(day,-(@NoOfDays-(no_of_day-1)),@To) as end_time, no_of_day-1 as no_of_day
	from dates d
	where (no_of_day-1) > 0 --and DATENAME(WEEKDAY,d.start_time) NOT IN ('Saturday','Sunday')
)
select start_time,end_time into #event_time_table from dates d 
where DATENAME(WEEKDAY,d.start_time) NOT IN ('Saturday','Sunday');

--select * from #event_time_table;

select [@From-UTC] = convert(smalldatetime,@From), [@To-UTC] = convert(smalldatetime,@To), [@NoOfDays] = @NoOfDays
		--,FORMAT(@From,N'HH:mm')
;with t_cpu_per_batch as (
	select collection_time, max(host_cpu_percent) as host_cpu_percent
	from dbo.who_is_active w join #event_time_table tf on w.collection_time between tf.start_time and tf.end_time
	group by collection_time
)
select collection_date_utc = FORMAT(cast(convert(date,collection_time) as smalldatetime)+convert(smalldatetime,FORMAT(@From,N'HH:mm')),N'yyyy-MM-dd HH:mm')
		,data_point_counts = count(*) ,host_cpu_percent = AVG(host_cpu_percent) ,host_cpu_max = MAX(host_cpu_percent) ,host_cpu_min = MIN(host_cpu_percent)
from t_cpu_per_batch s
group by convert(date,collection_time)
order by collection_date_utc desc;
go

