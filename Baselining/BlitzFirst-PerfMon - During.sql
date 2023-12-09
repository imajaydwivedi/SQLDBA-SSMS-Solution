use DBA;

-- select distinct CheckDate from dbo.BlitzFirst order by CheckDate DESC
--	https://blogs.msdn.microsoft.com/psssql/2013/09/23/interpreting-the-counter-values-from-sys-dm_os_performance_counters/

DECLARE @p_CheckDate datetimeoffset
SET @p_CheckDate = '2019-03-06 22:00:01.1643513 -06:00';

--select * from [dbo].BlitzFirst_PerfmonStats_Deltas2 where CheckDate = @p_CheckDate;
select @p_CheckDate as [@p_CheckDate], * from [dbo].BlitzFirst_PerfmonStats_Actuals2 
where CheckDate = @p_CheckDate
	and counter_name in ('Forwarded Records/sec','Full Scans/sec','Page Splits/sec','Workfiles Created/sec','Worktables Created/sec','Page life expectancy','Batch Requests/sec','Page reads/sec','Page writes/sec')


SET @p_CheckDate = '2019-03-05 22:00:00.9397862 -06:00';

--select * from [dbo].BlitzFirst_PerfmonStats_Deltas2 where CheckDate = @p_CheckDate;
select @p_CheckDate as [@p_CheckDate], * from [dbo].BlitzFirst_PerfmonStats_Actuals2 
where CheckDate = @p_CheckDate
	and counter_name in ('Forwarded Records/sec','Full Scans/sec','Page Splits/sec','Workfiles Created/sec','Worktables Created/sec','Page life expectancy','Batch Requests/sec','Page reads/sec','Page writes/sec')
