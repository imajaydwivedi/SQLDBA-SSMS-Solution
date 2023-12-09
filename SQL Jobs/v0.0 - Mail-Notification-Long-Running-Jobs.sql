USE DBA;
/*
--	DROP TABLE  DBA.dbo.SqlAgentJobs
--	TRUNCATE TABLE  DBA.dbo.SqlAgentJobs
--	alter table DBA.dbo.SqlAgentJobs alter column [Running Since(Hrs)] as datediff(hour,[Running Since],getdate()),
CREATE TABLE DBA.dbo.SqlAgentJobs
(	ID INT IDENTITY(1,1),
	JobName varchar(255) NOT NULL,
	Instance_Id bigint,
	[Expected-Max-Duration(Min)] BIGINT,
	[Ignore] bit default 0,
	[Running Since] datetime2,
	[Running Since(Hrs)] as datediff(hour,[Running Since],getdate()),
	[<3-Hrs] bigint,
	[3-Hrs] bigint,
	[6-Hrs] bigint,
	[9-Hrs] bigint,
	[12-Hrs] bigint,
	[18-Hrs] bigint,
	[24-Hrs] bigint,
	[36-Hrs] bigint,
	[48-Hrs] bigint,
	CollectionTime datetime2 default getdate()
)
GO

INSERT DBA.dbo.SqlAgentJobs
(JobName, [Expected-Max-Duration(Min)],[Ignore])
SELECT	[JobName] = j.name, 
		[Expected-Max-Duration(Min)] = AVG( ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60) ),
		[Ignore] = (CASE WHEN EXISTS (select  v.name as jobname, c.name as category from msdb.dbo.sysjobs_view as v left join msdb.dbo.syscategories as c on c.category_id = v.category_id where c.name like 'repl%' AND v.name = j.name) then 1 else 0 end)
FROM	msdb.dbo.sysjobhistory AS h
INNER JOIN msdb.dbo.sysjobs AS j
	ON	h.job_id = j.job_id
WHERE	h.step_id = 0
AND j.name NOT IN (select t.JobName from DBA.dbo.SqlAgentJobs as t)
GROUP BY j.name
ORDER BY [Expected-Max-Duration(Min)] DESC;
--	(98 rows affected)
GO

update dbo.SqlAgentJobs
set [Expected-Max-Duration(Min)] = 180
where Ignore = 0
and [Expected-Max-Duration(Min)] > 180
--	(9 rows affected)

update dbo.SqlAgentJobs
set Ignore = 1
where JobName like 'DBA%'
--	(34 rows affected)

SELECT * 
FROM dbo.SqlAgentJobs 
where Ignore = 0
*/
--select * FROM dbo.SqlAgentJobs where Ignore = 0;


SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#JobPastHistory') IS NOT NULL
	DROP TABLE #JobPastHistory;
;with t_history as
(
	/* Find Job Execution History more recent from Base Table */
	select	j.name as JobName, h.instance_id, h.run_date,
			Total_mins = ((run_duration/10000) * 60 ) + (run_duration/100%100) + (CASE when run_duration%100 > 29 THEN 1 ELSE 0 end)
	from msdb..sysjobs j
	inner join msdb..sysjobhistory h
	on h.job_id = j.job_id
	where step_id = 0
	AND EXISTS (SELECT 1 FROM DBA.dbo.SqlAgentJobs as b WHERE b.JobName = j.name and b.Ignore = 0 and h.instance_id > isnull(b.instance_id,0))
)
select	*
		,[TimeRange] = case	when Total_mins/60 >= 48 then '48-Hrs'
							when Total_mins/60 >= 36 then '36-Hrs'
							when Total_mins/60 >= 24 then '24-Hrs'
							when Total_mins/60 >= 18 then '18-Hrs'
							when Total_mins/60 >= 12 then '12-Hrs'
							when Total_mins/60 >= 9 then '9-Hrs'
							when Total_mins/60 >= 6 then '6-Hrs'
							when Total_mins/60 >= 3 then '3-Hrs'
							else '<3-Hrs'
						end
into	#JobPastHistory
from	t_history;

IF OBJECT_ID('tempdb..#JobActivityMonitor') IS NOT NULL
	DROP TABLE #JobActivityMonitor;
;with t_pivot AS
(
	select JobName, [<3-Hrs], [3-Hrs], [6-Hrs], [9-Hrs], [12-Hrs], [18-Hrs], [24-Hrs], [36-Hrs], [48-Hrs]
	FROM (	select JobName, instance_id, TimeRange from #JobPastHistory  ) up
	PIVOT ( COUNT(instance_id) FOR TimeRange IN ([<3-Hrs], [3-Hrs], [6-Hrs], [9-Hrs], [12-Hrs], [18-Hrs], [24-Hrs], [36-Hrs], [48-Hrs]) ) As pvt
)
,t_history_info AS
(
	select jp.JobName, jh.max_instance_id as instance_id, [<3-Hrs], [3-Hrs], [6-Hrs], [9-Hrs], [12-Hrs], [18-Hrs], [24-Hrs], [36-Hrs], [48-Hrs]
	from t_pivot as jp join (select JobName, max(instance_id) as max_instance_id from #JobPastHistory group by JobName) as jh
	on jp.JobName = jh.JobName
)
,t_jobActivityMonitor AS
(
	SELECT
			ja.job_id,
			j.name AS JobName,
			ja.start_execution_date,      
			ISNULL(last_executed_step_id,0)+1 AS current_executed_step_id,
			Js.step_name
	FROM msdb.dbo.sysjobactivity ja 
	LEFT JOIN msdb.dbo.sysjobhistory jh 
		ON ja.job_history_id = jh.instance_id
	JOIN msdb.dbo.sysjobs j 
	ON ja.job_id = j.job_id
	JOIN msdb.dbo.sysjobsteps js
		ON ja.job_id = js.job_id
		AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
	WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
	AND start_execution_date is not null
	AND stop_execution_date is null
)
select	JobName = COALESCE(a.JobName, h.JobName), h.instance_id, [Running Since] = a.start_execution_date
		,[<3-Hrs], [3-Hrs], [6-Hrs], [9-Hrs], [12-Hrs], [18-Hrs], [24-Hrs], [36-Hrs], [48-Hrs]
into	#JobActivityMonitor
from	t_jobActivityMonitor as a full outer join t_history_info as h on h.JobName = a.JobName

-- Step 01 - Remove Previous Running Jobs ([Running Since] = NULL)
UPDATE DBA.dbo.SqlAgentJobs
SET [Running Since] = NULL
WHERE [Running Since] IS NOT NULL;

-- Step 02 - Update table with current Running Jobs
UPDATE	b
SET		[Running Since] = a.[Running Since]
FROM	DBA.dbo.SqlAgentJobs b JOIN #JobActivityMonitor a ON a.JobName = b.JobName AND a.[Running Since] IS NOT NULL;

-- Step 03 - Update other columns like Instance_Id, [<3-Hrs], [3-Hrs], [6-Hrs], [9-Hrs], [18-Hrs], [24-Hrs], [36-Hrs], [48-Hrs]
UPDATE	b
SET		Instance_Id = a.instance_id,
		[<3-Hrs] = ISNULL(b.[<3-Hrs],0) + ISNULL(a.[<3-Hrs],0),
		[3-Hrs] = ISNULL(b.[3-Hrs],0) + ISNULL(a.[3-Hrs],0),
		[6-Hrs] = ISNULL(b.[6-Hrs],0) + ISNULL(a.[6-Hrs],0),
		[9-Hrs] = ISNULL(b.[9-Hrs],0) + ISNULL(a.[9-Hrs],0),
		[12-Hrs] = ISNULL(b.[12-Hrs],0) + ISNULL(a.[12-Hrs],0),
		[18-Hrs] = ISNULL(b.[18-Hrs],0) + ISNULL(a.[18-Hrs],0),
		[24-Hrs] = ISNULL(b.[24-Hrs],0) + ISNULL(a.[24-Hrs],0),
		[36-Hrs] = ISNULL(b.[36-Hrs],0) + ISNULL(a.[36-Hrs],0),
		[48-Hrs] = ISNULL(b.[48-Hrs],0) + ISNULL(a.[48-Hrs],0)
FROM	DBA.dbo.SqlAgentJobs b JOIN #JobActivityMonitor a ON a.JobName = b.JobName AND a.instance_id IS NOT NULL

-- Step 04 - Drop Mail
DECLARE @tableHTML  NVARCHAR(MAX) ;
DECLARE @subject VARCHAR(200);

SET @subject = 'Long Running Jobs - '+CAST(CAST(GETDATE() AS DATE) AS VARCHAR(20));
--SELECT @subject

SET @tableHTML =  N'
<style>
#JobActivity {
    font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
    border-collapse: collapse;
    width: 100%;
}

#JobActivity td, #JobActivity th {
    border: 1px solid #ddd;
    padding: 8px;
}

#JobActivity tr:nth-child(even){background-color: #f2f2f2;}

#JobActivity tr:hover {background-color: #ddd;}

#JobActivity th {
    padding-top: 12px;
    padding-bottom: 12px;
    text-align: left;
    background-color: #4CAF50;
    color: white;
}
</style>'+
    N'<H1>'+@subject+'</H1>' +  
    N'<table border="1" id="JobActivity">' +
		--N'<caption>Currently Running Jobs that Need Attention</caption>'+
	N'<thead>
		  <tr><th rowspan=2>JobName</th>' + 
			N'<th rowspan=2>Expected-Duration<br>(Minutes)</th>' +  
			N'<th rowspan=2>Running Since</th>'+
			N'<th rowspan=2>Running Since(Hrs)</th>'+
			N'<th colspan=9>No of times Job crossed below Thresholds</th>
		  </tr>
		  <tr>'+
			N'<th>< 3 Hrs</th>'+
			N'<th>> 3 Hrs</th>' +  
			N'<th>> 6 Hrs</th>'+
			N'<th>> 9 Hrs</th>'+
			N'<th>> 12 Hrs</th>'+
			N'<th>> 18 Hrs</th>'+
			N'<th>> 24 Hrs</th>'+
			N'<th>> 36 Hrs</th>'+
			N'<th>> 48 Hrs</th>
		  </tr>
	  </thead>' +  
	N'<tbody>'+
    CAST ( ( SELECT td = JobName, '',  
                    td = CAST([Expected-Max-Duration(Min)] AS VARCHAR(20)), '',  
                    td = CAST([Running Since] AS VARCHAR(30)), '',  
                    td = CAST([Running Since(Hrs)] AS VARCHAR(20)), '',  
                    td = CAST(ISNULL([<3-Hrs],0) AS VARCHAR(20)), '',  
					td = CAST(ISNULL([3-Hrs],0) AS VARCHAR(20)), '', 
					td = CAST(ISNULL([6-Hrs],0) AS VARCHAR(20)), '',  
					td = CAST(ISNULL([9-Hrs],0) AS VARCHAR(20)), '', 
					td = CAST(ISNULL([12-Hrs],0) AS VARCHAR(20)), '',  
					td = CAST(ISNULL([18-Hrs],0) AS VARCHAR(20)), '', 
					td = CAST(ISNULL([24-Hrs],0) AS VARCHAR(20)), '',  
					td = CAST(ISNULL([36-Hrs],0) AS VARCHAR(20)), '', 
                    td = CAST(ISNULL([48-Hrs],0) AS VARCHAR(20))  
              FROM DBA.dbo.SqlAgentJobs as j
				WHERE j.Ignore = 0
				AND j.[Running Since] IS NOT NULL
				AND j.[Running Since(Hrs)] >= 3.0
              FOR XML PATH('tr'), TYPE   
    ) AS NVARCHAR(MAX) ) +  
    N'</tbody></table>
	
<p></p><br><br>
Thanks & Regards,<br>
SQLAlerts<br>
-- Alert from job [DBA - Long Running Jobs]
	' ;  

IF @tableHTML IS NOT NULL
BEGIN
	EXEC msdb.dbo.sp_send_dbmail 
		@recipients='DBA@contso.com',  
		@subject = @subject,  
		@body = @tableHTML,  
		@body_format = 'HTML' ;
END
ELSE
	PRINT 'No Long Running job found.';

SELECT * FROM DBA.dbo.SqlAgentJobs as j WHERE j.Ignore = 0	AND j.[Running Since] IS NOT NULL
	--AND (DATEDIFF(MINUTE,[Running Since],GETDATE()) > [Expected-Max-Duration(Min)] AND DATEDIFF(MINUTE,[Running Since],GETDATE()) > 60)
