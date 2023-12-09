DECLARE @job_name varchar(500);
--SET @job_name = '(dba) Run-WhoIsActive';

;WITH T_Schedules AS
(
	select J.name AS JobName,
		   SS.name AS ScheduleName,                    
		   CASE(SS.freq_type)
				WHEN 1  THEN 'Once'
				WHEN 4  THEN 'Daily'
				WHEN 8  THEN (case when (SS.freq_recurrence_factor > 1) then  'Every ' + convert(varchar(3),SS.freq_recurrence_factor) + ' Weeks'  else 'Weekly'  end)
				WHEN 16 THEN (case when (SS.freq_recurrence_factor > 1) then  'Every ' + convert(varchar(3),SS.freq_recurrence_factor) + ' Months' else 'Monthly' end)
				WHEN 32 THEN 'Every ' + convert(varchar(3),SS.freq_recurrence_factor) + ' Months' -- RELATIVE
				WHEN 64 THEN 'SQL Startup'
				WHEN 128 THEN 'SQL Idle'
				ELSE '??'
			END AS Frequency,  
		   CASE
				WHEN (freq_type = 1)                       then 'One time only'
				WHEN (freq_type = 4 and freq_interval = 1) then 'Every Day'
				WHEN (freq_type = 4 and freq_interval > 1) then 'Every ' + convert(varchar(10),freq_interval) + ' Days'
				WHEN (freq_type = 8) then (select 'Weekly Schedule' = MIN(D1+ D2+D3+D4+D5+D6+D7 )
											from (select SS.schedule_id,
															freq_interval, 
															'D1' = CASE WHEN (freq_interval & 1  <> 0) then 'Sun ' ELSE '' END,
															'D2' = CASE WHEN (freq_interval & 2  <> 0) then 'Mon '  ELSE '' END,
															'D3' = CASE WHEN (freq_interval & 4  <> 0) then 'Tue '  ELSE '' END,
															'D4' = CASE WHEN (freq_interval & 8  <> 0) then 'Wed '  ELSE '' END,
														'D5' = CASE WHEN (freq_interval & 16 <> 0) then 'Thu '  ELSE '' END,
															'D6' = CASE WHEN (freq_interval & 32 <> 0) then 'Fri '  ELSE '' END,
															'D7' = CASE WHEN (freq_interval & 64 <> 0) then 'Sat '  ELSE '' END
														from msdb..sysschedules ss
													where freq_type = 8
												) as F
											where schedule_id = JS.schedule_id
										)
				WHEN (freq_type = 16) then 'Day ' + convert(varchar(2),freq_interval) 
				WHEN (freq_type = 32) then (select  freq_rel + WDAY 
											from (select SS.schedule_id,
															'freq_rel' = CASE(freq_relative_interval)
																		WHEN 1 then 'First'
																		WHEN 2 then 'Second'
																		WHEN 4 then 'Third'
																		WHEN 8 then 'Fourth'
																		WHEN 16 then 'Last'
																		ELSE '??'
																		END,
														'WDAY'     = CASE (freq_interval)
																		WHEN 1 then ' Sun'
																		WHEN 2 then ' Mon'
																		WHEN 3 then ' Tue'
																		WHEN 4 then ' Wed'
																		WHEN 5 then ' Thu'
																		WHEN 6 then ' Fri'
																		WHEN 7 then ' Sat'
																		WHEN 8 then ' Day'
																		WHEN 9 then ' Weekday'
																		WHEN 10 then ' Weekend'
																		ELSE '??'
																		END
													from msdb..sysschedules SS
													where SS.freq_type = 32
													) as WS 
											where WS.schedule_id = SS.schedule_id
											) 
			END AS Interval,
			CASE (freq_subday_type)
				WHEN 1 then   left(stuff((stuff((replicate('0', 6 - len(active_start_time)))+ convert(varchar(6),active_start_time),3,0,':')),6,0,':'),8)
				WHEN 2 then 'Every ' + convert(varchar(10),freq_subday_interval) + ' seconds'
				WHEN 4 then 'Every ' + convert(varchar(10),freq_subday_interval) + ' minutes'
				WHEN 8 then 'Every ' + convert(varchar(10),freq_subday_interval) + ' hours'
				ELSE '??'
			END AS [Time],
			CASE JS.next_run_date
				WHEN 0 THEN cast('n/a' as char(10))
				ELSE convert(char(10), convert(datetime, convert(char(8),JS.next_run_date)),120)  + ' ' + left(stuff((stuff((replicate('0', 6 - len(next_run_time)))+ convert(varchar(6),next_run_time),3,0,':')),6,0,':'),8)
			END AS NextRunTime
	from msdb.dbo.sysjobs J
	left join msdb.dbo.sysjobschedules JS on J.job_id = JS.job_id  
	left join msdb.dbo.sysschedules SS on SS.schedule_id = JS.schedule_id
	where J.enabled = 1 and SS.enabled = 1
)
SELECT 'Executing-Jobs' as RunningQuery,
	Concat
    (
        RIGHT('00'+CAST(ISNULL((datediff(second,ja.start_execution_date,GETDATE()) / 3600 / 24), 0) AS VARCHAR(2)),2)
        ,' '
        ,RIGHT('00'+CAST(ISNULL(datediff(second,ja.start_execution_date,GETDATE()) / 3600  % 24, 0) AS VARCHAR(2)),2)
        ,':'
        ,RIGHT('00'+CAST(ISNULL(datediff(second,ja.start_execution_date,GETDATE()) / 60 % 60, 0) AS VARCHAR(2)),2)
        ,':'
        ,RIGHT('00'+CAST(ISNULL(datediff(second,ja.start_execution_date,GETDATE()) % 3600 % 60, 0) AS VARCHAR(2)),2)
    ) as [dd hh:mm:ss],
    j.name AS job_name,
    ja.start_execution_date,
	'Step '+cast(ISNULL(last_executed_step_id,0)+1 as varchar)+' {'+Js.step_name+'}' as step_name
	,s.Frequency ,s.Interval ,s.Time ,s.NextRunTime ,DATEDIFF(minute,GETDATE(),s.NextRunTime) as [starts in(min)]
FROM msdb.dbo.sysjobactivity ja 
LEFT JOIN msdb.dbo.sysjobhistory jh 
    ON ja.job_history_id = jh.instance_id
JOIN msdb.dbo.sysjobs j 
ON ja.job_id = j.job_id
JOIN msdb.dbo.sysjobsteps js
    ON ja.job_id = js.job_id
    AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
LEFT JOIN T_Schedules s
ON s.JobName = j.name
WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
AND start_execution_date is not null
AND stop_execution_date is null
AND (UPPER(j.name) = UPPER(@job_name) OR @job_name IS NULL)
ORDER BY ja.start_execution_date


--SELECT [JobName], [Instance_Id], [Total_Executions], [Total_Success_Count], [Total_Stopped_Count], [Total_Failed_Count], 
--	[Continous_Failures], [Last_Successful_ExecutionTime], [Running_Since], [Running_StepName], 
--	[Running_Since_Min], [Next_RunTime], [<10-Min], [10-Min], [30-Min], [1-Hrs], [2-Hrs], [3-Hrs], 
--	[6-Hrs], [9-Hrs], [12-Hrs], [18-Hrs], [24-Hrs], [36-Hrs], [48-Hrs], [UpdatedDate]
--FROM dbo.sql_agent_job_stats as sajs

