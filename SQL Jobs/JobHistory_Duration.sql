SET NOCOUNT ON;

/* Get Job Duration History */
declare @job_name varchar(255);
declare @days_history int = 3;
declare @page_no int = 1;
declare @page_size int = 500;
declare @params nvarchar(max);
declare @sql nvarchar(max);
set @params = N'@job_name varchar(255), @days_history int = 3, @page_no int, @page_size int';

set quoted_identifier off;
set @sql = "
select	jh.[RunDateTime],
		[JobName] = j.name,
		jh.[RunDuration (d.HH:MM:SS)],
		jh.RunDurationMinutes
from msdb.dbo.sysjobs_view j
cross apply (
	select	[RunDateTime] = DATETIMEFROMPARTS(
								   LEFT(padded_run_date, 4),         -- year
								   SUBSTRING(padded_run_date, 5, 2), -- month
								   RIGHT(padded_run_date, 2),        -- day
								   LEFT(padded_run_time, 2),         -- hour
								   SUBSTRING(padded_run_time, 3, 2), -- minute
								   RIGHT(padded_run_time, 2),        -- second
								   0),          -- millisecond
			[RunDuration (d.HH:MM:SS)] = CASE
								   WHEN jh.run_duration > 235959
									   THEN CAST((CAST(LEFT(CAST(jh.run_duration AS VARCHAR), LEN(CAST(jh.run_duration AS VARCHAR)) - 4) AS INT) / 24) AS VARCHAR) + '.' + RIGHT('00' + CAST(CAST(LEFT(CAST(jh.run_duration AS VARCHAR), LEN(CAST(jh.run_duration AS VARCHAR)) - 4) AS INT) % 24 AS VARCHAR), 2) + ':' + STUFF(CAST(RIGHT(CAST(jh.run_duration AS VARCHAR), 4) AS VARCHAR(6)), 3, 0, ':')
								   ELSE STUFF(STUFF(RIGHT(REPLICATE('0', 6) + CAST(jh.run_duration AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':')
								   END,
			[RunDurationMinutes] = ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60)
			,run_date ,run_time
	from msdb.dbo.sysjobhistory jh
	CROSS APPLY ( SELECT RIGHT('000000' + CAST(jh.run_time AS VARCHAR(6)), 6), RIGHT('00000000' + CAST(jh.run_date AS VARCHAR(8)), 8) ) AS shp(padded_run_time, padded_run_date)
	where jh.job_id = j.job_id and jh.step_id = 0
	and jh.run_date >= convert(int,convert(varchar,convert(date,dateadd(day,-@days_history,getdate())),112))
) jh
where 1=1
"+(case when @job_name is null then '--' else '' end)+"and j.name = @job_name
order by jh.run_date ,jh.run_time, j.name
offset ((@page_no-1)*@page_size) rows fetch next @page_size rows only
";
set quoted_identifier off;

exec sp_Executesql @sql, @params, @job_name, @days_history, @page_no, @page_size;
go

/* Get Job Duration History In Percentiles */
declare @job_name varchar(255);
declare @days_history int = 90;
declare @page_no int = 1;
declare @page_size int = 500;
declare @params nvarchar(max);
declare @sql nvarchar(max);
set @params = N'@job_name varchar(255), @days_history int = 3, @page_no int, @page_size int';

set quoted_identifier off;
set @sql = "
select	[JobName] = j.name, [Executions], [Executions-Success], [Executions-Failed],
		[0.8 pcntile (min)] = floor([0.8 pcntile]),
		[0.9 pcntile (min)] = floor([0.9 pcntile]),
		[0.95 pcntile (min)] = floor([0.95 pcntile]),
		[0.99 pcntile (min)] = floor([0.99 pcntile]),
		[0.999 pcntile (min)] = floor([0.999 pcntile]),
		[0.999999 pcntile (min)] = floor([0.999999 pcntile])
from msdb.dbo.sysjobs_view j with (nolock)
join (
	select	distinct job_id, 
			[0.8 pcntile] = PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60)) OVER (PARTITION BY jh.job_id),
			[0.9 pcntile] = PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60)) OVER (PARTITION BY jh.job_id),
			[0.95 pcntile] = PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60)) OVER (PARTITION BY jh.job_id),
			[0.99 pcntile] = PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60)) OVER (PARTITION BY jh.job_id),
			[0.999 pcntile] = PERCENTILE_CONT(0.999) WITHIN GROUP (ORDER BY ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60)) OVER (PARTITION BY jh.job_id),
			[0.999999 pcntile] = PERCENTILE_CONT(0.99999) WITHIN GROUP (ORDER BY ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60)) OVER (PARTITION BY jh.job_id),
			[Executions] = count(*) over (partition by jh.job_id),
			[Executions-Failed] = sum((case when run_status in (0,3) then 1 else 0 end)) over (partition by jh.job_id),
			[Executions-Success] = sum((case when run_status = 1 then 1 else 0 end)) over (partition by jh.job_id)
	from msdb.dbo.sysjobhistory jh with (nolock)
	where jh.step_id = 0
	and jh.run_date >= convert(int,convert(varchar,convert(date,dateadd(day,-@days_history,getdate())),112))
) jh
on jh.job_id = j.job_id
where 1=1
"+(case when @job_name is null then '--' else '' end)+" and j.name = @job_name
--and [Executions] > 1
order by j.name
";
set quoted_identifier off;

--print @sql

exec sp_Executesql @sql, @params, @job_name, @days_history, @page_no, @page_size;
go


