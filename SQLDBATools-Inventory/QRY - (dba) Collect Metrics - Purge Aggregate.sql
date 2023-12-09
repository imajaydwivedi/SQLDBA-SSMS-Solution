set nocount on;
set xact_abort on;

-- Set config variables
declare @retention_days int = 15;
declare @time_interval_minutes tinyint = 10;

-- declare local variables
declare @r int = 1;
declare @date_filter date;
set @date_filter = CONVERT(date,DATEADD(day,-@retention_days,GETDATE()));

-- create table for storing deleted data for aggregation
if OBJECT_ID('tempdb..#dm_os_performance_counters_nonsql_aggregated') is not null
	drop table #dm_os_performance_counters_nonsql_aggregated;
CREATE TABLE #dm_os_performance_counters_nonsql_aggregated
(
	[collection_time] [datetime2] NOT NULL,
	[server_name] [varchar](256) NOT NULL,
	[object_name] [nvarchar](128) NOT NULL,
	[counter_name] [nvarchar](128) NOT NULL,
	[instance_name] [nvarchar](128) NULL,
	[cntr_value] [bigint] NOT NULL,
	[cntr_type] [int] NOT NULL,
	[id] [smallint] NOT NULL
);

while @r > 0
begin
	truncate table #dm_os_performance_counters_nonsql_aggregated;

	delete top (10000) [dbo].[dm_os_performance_counters_nonsql]
	output deleted.*
	into #dm_os_performance_counters_nonsql_aggregated
	where collection_time < @date_filter;
	set @r = @@ROWCOUNT;

	insert [dbo].[dm_os_performance_counters_nonsql_aggregated]
	select	[collection_time] = convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)),
			server_name, [object_name], counter_name, instance_name,
			cntr_value = AVG(cntr_value),
			cntr_type,
			id = ROW_NUMBER()OVER(ORDER BY GETDATE())
	from #dm_os_performance_counters_nonsql_aggregated as omc
	group by convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)), 
			server_name, [object_name], counter_name, instance_name, cntr_type

	print cast(@@ROWCOUNT as varchar)+ ' rows inserted into aggregated table';
end
go

-- select * from [dm_os_performance_counters_nonsql_aggregated]