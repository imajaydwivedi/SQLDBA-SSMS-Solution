SET NOCOUNT ON;

-- If exists any log reader/distribution job that is not running
IF EXISTS (SELECT * FROM msdb.dbo.sysjobactivity ja LEFT JOIN msdb.dbo.sysjobhistory jh ON ja.job_history_id = jh.instance_id JOIN msdb.dbo.sysjobs j ON ja.job_id = j.job_id JOIN msdb.dbo.sysjobsteps js	ON ja.job_id = js.job_id AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id JOIN msdb..syscategories as cg ON cg.category_id = j.category_id	WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
	and cg.name in ('REPL-LogReader','REPL-Distribution')
	and DBA.dbo.fn_IsJobRunning(j.name) = 0
)
BEGIN
	DECLARE @tableHTML  NVARCHAR(MAX) ;  

	;WITH T_Status AS 
	(
		SELECT	j.name AS JobName,
			--ja.start_execution_date,      
			--ISNULL(last_executed_step_id,0)+1 AS current_executed_step_id,
			--Js.step_name
			cg.name as Category
			--,DBA.dbo.fn_IsJobRunning(j.name) as is_Running
		FROM msdb.dbo.sysjobactivity ja 
		LEFT JOIN msdb.dbo.sysjobhistory jh 
		ON ja.job_history_id = jh.instance_id
		JOIN msdb.dbo.sysjobs j 
		ON ja.job_id = j.job_id
		JOIN msdb.dbo.sysjobsteps js
		ON ja.job_id = js.job_id
		AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
		JOIN msdb..syscategories as cg
		ON cg.category_id = j.category_id
		WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
		and cg.name in ('REPL-LogReader','REPL-Distribution')
		--AND cg.name like '%Repl%'
		and DBA.dbo.fn_IsJobRunning(j.name) = 0
	)  
	
	SELECT @tableHTML =  
		N'<H2>Below Replication Agent Jobs are found in STOPPED state</H2>' +  
		N'<table border="1">' +  
		N'<tr><th>Job Name</th><th>Category</th></tr>' +  
		CAST ( ( SELECT td = j.JobName,       '',    
						td = Category  
				  FROM T_Status AS j
				  FOR XML PATH('tr'), TYPE   
		) AS NVARCHAR(MAX) ) +  
		N'</table>' ;  

	--print @tableHTML

	SET @tableHTML = @tableHTML + '<br>
<p>
Regards,<br>
SQLAlerts<br>
-- Alert coming from Job [DBA - Replication - Stoped Jobs]<br>
</p>
';
	
	EXEC msdb.dbo.sp_send_dbmail 
		@recipients='sqlagentservice@gmail.com',  
		@subject = 'Replication Agent Jobs - Stopped State Issue',  
		@body = @tableHTML,  
		@body_format = 'HTML' ;  
	
END
