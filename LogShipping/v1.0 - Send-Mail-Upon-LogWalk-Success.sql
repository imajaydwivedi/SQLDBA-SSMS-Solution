DECLARE @_mailSubject VARCHAR(255)
		,@_mailBody VARCHAR(4000)
		,@p_Mail_TO VARCHAR(1000)
		,@p_Mail_CC VARCHAR(1000)
		,@p_JobName VARCHAR(2000);

DECLARE @_IsInvokedByAutomation BIT = 0,
		@_RunDurationMinutes INT,
		@_IsSuccessFull BIT = 0;

SET @p_JobName = 'DBA Log Walk - Restore Staging as Staging';

SELECT	TOP 1
		@_IsSuccessFull = CASE WHEN h.run_status = 1 THEN 1 ELSE 0 END,
		@_RunDurationMinutes = ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60),
		@_IsInvokedByAutomation = (CASE WHEN h.message like 'The job succeeded.  The Job was invoked by User contso\ProdSQL.%' THEN 1 ELSE 0 END)
FROM	msdb.dbo.sysjobs j 
INNER JOIN msdb.dbo.sysjobhistory h 
	ON	j.job_id = h.job_id 
WHERE	j.name = @p_JobName
	AND step_id = 0
ORDER BY j.name, h.instance_id desc;

--SET @p_Mail_TO = 'DBA@contso.com; App-Team@contso.com';
SET @p_Mail_TO = 'ajay.dwivedi@contso.com';
SET @_mailSubject = 'SQL Agent Job [DBA Log Walk - Restore Staging as Staging] is Successfull';
SET @_mailBody = 'Dear DBA Team,

SQL Agent Job '+QUOTENAME(@p_JobName)+' has been successfully executed. No further action required.


Thanks & Regards,
SQL Alerts
DBA@contso.com
-- Alert Coming from SQL Agent Job [DBA Log Walk - Restore Staging as Staging] - Step 04. 
		'
IF(@_IsSuccessFull = 0)
BEGIN
	EXEC msdb..sp_send_dbmail	@profile_name = @@servername,
								@recipients = @p_Mail_TO,
								--@copy_recipients =  @p_Mail_CC,
								@subject = @_mailSubject,
								@body = @_mailBody;
END
