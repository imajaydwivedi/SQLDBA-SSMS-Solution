/* Purge [dbo].[WaitStats] */

set nocount on;
set xact_abort on;

-- Set config variables
declare @retention_days int = 7;
declare @time_interval_minutes tinyint = 10;

-- declare local variables
declare @r int = 1;
declare @date_filter date;
declare @date_filter_lower datetime2; -- filter for deleting data in chunks
declare @date_filter_upper datetime2; -- filter for deleting data in chunks

-- create table for storing deleted data for aggregation
if OBJECT_ID('tempdb..#WaitStats_aggregated') is not null
	drop table #WaitStats_aggregated;
CREATE TABLE #WaitStats_aggregated
(
	[Collection_Time] [datetime2] NOT NULL,
	[RowNum] [smallint] NOT NULL,
	[WaitType] [nvarchar](120) NOT NULL,
	[Wait_S] [decimal](20, 2) NOT NULL,
	[Resource_S] [decimal](20, 2) NOT NULL,
	[Signal_S] [decimal](20, 2) NOT NULL,
	[WaitCount] [bigint] NOT NULL,
	[Percentage] [decimal](5, 2) NULL,
	[AvgWait_S] AS ([Wait_S]/[WaitCount]),
	[AvgRes_S] AS ([Resource_S]/[WaitCount]),
	[AvgSig_S] AS ([Signal_S]/[WaitCount]),
	[Help_URL] AS (CONVERT([xml],'https://www.sqlskills.com/help/waits/'+[WaitType]))
);

set @date_filter = CONVERT(date,DATEADD(day,-@retention_days,GETDATE()));
select @date_filter_lower = dbo.aggregate_time(min(collection_time),@time_interval_minutes*2) from [dbo].[WaitStats] where [Collection_Time] < @date_filter;
set @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_lower);

--select [@date_filter] = @date_filter, [@date_filter_lower] = @date_filter_lower, [@date_filter_upper] = @date_filter_upper;

while @r > 0 or exists (select * from [dbo].[WaitStats] where [Collection_Time] < @date_filter)
begin
	truncate table #WaitStats_aggregated;

	delete [dbo].[WaitStats]
	output deleted.Collection_Time, deleted.RowNum, deleted.WaitType, deleted.Wait_S, deleted.Resource_S, deleted.Signal_S, deleted.WaitCount, deleted.Percentage
	into #WaitStats_aggregated
	where [Collection_Time] < @date_filter
		and ([Collection_Time] >= @date_filter_lower and [Collection_Time] < @date_filter_upper);

	set @r = @@ROWCOUNT;

	if @r > 0
	begin
		-- Insert 1st collection batch in the @time_interval_minutes range
		insert [dbo].[WaitStats_aggregated]
		(Collection_Time, RowNum, WaitType, Wait_S, Resource_S, Signal_S, WaitCount, Percentage)
		select	Collection_Time, RowNum, WaitType, Wait_S, Resource_S, Signal_S, WaitCount, Percentage
		from #WaitStats_aggregated as ws
		where [Collection_Time] in (select MIN(ag.Collection_Time) from #WaitStats_aggregated ag group by convert(smalldatetime,dbo.aggregate_time(ag.collection_time,@time_interval_minutes)) );

		print cast(@@ROWCOUNT as varchar)+ ' rows inserted into aggregated table';
	end
	
	select @date_filter_lower = @date_filter_upper, @date_filter_upper = DATEADD(MINUTE,@time_interval_minutes*2,@date_filter_upper);
end
