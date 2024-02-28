set nocount on;

declare @start_date int = '20220812'; --yyyymmdd
declare @end_date int = '20240102'; --yyyymmdd
declare @days_interval int = 5;
declare @sql nvarchar(max);
declare @params nvarchar(max);

/*	IMPORTANT: Create this INDEX first
create index [run_date] on [msdb].[dbo].[sysjobhistory] ([run_date]) include (instance_id)
with (fillfactor=100, maxdop=0, sort_in_tempdb = on)
go
*/

set @sql = N'DELETE FROM msdb.dbo.sysjobhistory WHERE run_date <= @purge_date -- start date '+convert(varchar,@start_date);
set @params = N'@purge_date int';

while (@start_date <= @end_date)
begin
	--exec msdb.dbo.sp_purge_jobhistory  @oldest_date=@start_date;
	exec sp_executesql @sql, @params, @purge_date = @start_date;
	print 'rows affected for @start_date ('+convert(varchar,@start_date)+') => '+convert(varchar,@@rowcount);

	set @start_date = cast(convert(varchar,dateadd(day,@days_interval,convert(date,convert(varchar,@start_date),112)),112) as int);
	--break;
end
GO

/*
USE [msdb]
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @jobhistory_max_rows=500000, 
		@jobhistory_max_rows_per_job=1000
GO
*/