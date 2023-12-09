/* Purge [dbo].[dm_os_memory_clerks] */

set nocount on;
set xact_abort on;

-- Set config variables
declare @retention_days int = 15;
declare @time_interval_minutes tinyint = 10;

-- declare local variables
declare @r int = 1;
declare @date_filter date;
declare @date_filter_lower datetime2; -- filter for deleting data in chunks
declare @date_filter_upper datetime2; -- filter for deleting data in chunks

-- create table for storing deleted data for aggregation
if OBJECT_ID('tempdb..#dm_os_memory_clerks') is not null
	drop table #dm_os_memory_clerks;
create table #dm_os_memory_clerks
(
	[collection_time] [datetime2] NOT NULL DEFAULT GETDATE(),
	[memory_clerk] [nvarchar](60) NOT NULL,
	[size_mb] [bigint] NULL
);

set @date_filter = CONVERT(date,DATEADD(day,-@retention_days,GETDATE()));
select @date_filter_lower = dbo.aggregate_time(min(collection_time),@time_interval_minutes*2) from [dbo].[dm_os_memory_clerks] where collection_time < @date_filter;
set @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_lower);

while @r > 0 or exists (select * from [dbo].[dm_os_memory_clerks] where collection_time < @date_filter)
begin
	truncate table #dm_os_memory_clerks;

	delete [dbo].[dm_os_memory_clerks]
	output deleted.collection_time, deleted.memory_clerk, deleted.size_mb
	into #dm_os_memory_clerks
	where collection_time < @date_filter
		and (collection_time >= @date_filter_lower and collection_time < @date_filter_upper);
	
	set @r = @@ROWCOUNT;

	if @r > 0
	begin
		insert [dbo].[dm_os_memory_clerks_aggregated]
		select	[collection_time] = convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)),
				[memory_clerk], 
				size_mb = AVG(size_mb)
		from #dm_os_memory_clerks as omc
		group by convert(smalldatetime,dbo.aggregate_time(collection_time,@time_interval_minutes)), [memory_clerk];

		print cast(@@ROWCOUNT as varchar)+ ' rows inserted into aggregated table';
	end

	select @date_filter_lower = @date_filter_upper, @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_upper);
end
