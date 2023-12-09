/* Purge [dbo].[dm_os_memory_clerks_aggregated] */

set nocount on;
set xact_abort on;

-- Set config variables
declare @retention_4_max_duration_months int = 12;
declare @retention_4_intermediate_duration_days int = 90;
declare @time_interval_minutes tinyint = 60; -- Hourly

-- declare local variables
declare @r int = 1;
declare @date_filter_4_max_duration date;
declare @date_filter_4_intermediate_duration date;
select	@date_filter_4_max_duration = CONVERT(date,DATEADD(MONTH,-@retention_4_max_duration_months,GETDATE())),
		@date_filter_4_intermediate_duration = CONVERT(date,DATEADD(day,-@retention_4_intermediate_duration_days,GETDATE()));

set @r = 1; 
while @r > 0 -- @retention_4_max_duration_months
begin
	delete top (10000) [dbo].[dm_os_memory_clerks_aggregated]
	where collection_time < @date_filter_4_max_duration;

	set @r = @@ROWCOUNT;
end


-- create table for storing deleted data for aggregation
if OBJECT_ID('tempdb..#dm_os_memory_clerks') is not null
	drop table #dm_os_memory_clerks;
create table #dm_os_memory_clerks
(
	[collection_time] [datetime2] NOT NULL DEFAULT GETDATE(),
	[memory_clerk] [nvarchar](60) NOT NULL,
	[size_mb] [bigint] NULL
);

set @r = 1; 
while @r > 0 -- @retention_4_intermediate_duration_days
begin
	truncate table #dm_os_memory_clerks;

	delete top (10000) [dbo].[dm_os_memory_clerks_aggregated]
	output deleted.collection_time, deleted.memory_clerk, deleted.size_mb
	into #dm_os_memory_clerks
	where collection_time < @date_filter_4_intermediate_duration;
	set @r = @@ROWCOUNT;

	insert [dbo].[dm_os_memory_clerks_aggregated]
	select	[collection_time] = convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)),
			[memory_clerk], 
			size_mb = AVG(size_mb)
	from #dm_os_memory_clerks as omc
	group by convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)), [memory_clerk];
end

select convert(smalldatetime,dbo.aggregate_time(DATEADD(hour,0,getdate()),10))
		,convert(smalldatetime,dbo.aggregate_time(DATEADD(hour,-48,getdate()),60))

