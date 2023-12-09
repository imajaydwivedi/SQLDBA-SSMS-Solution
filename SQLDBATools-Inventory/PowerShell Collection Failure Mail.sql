DECLARE @subject VARCHAR(200);
DECLARE @htmlBody VARCHAR(MAX);
DECLARE @p_recipients VARCHAR(2000);
DECLARE @ServerNames VARCHAR(8000);

IF EXISTS (
	select * from [Staging].[CollectionErrors] e
		where e.CollectionTime >= DATEADD(hour,-2,getdate())
		and e.Cmdlet = 'Collect-VolumeInfo'
)
BEGIN
	select @ServerNames = COALESCE(@ServerNames+', '+e.ServerName,e.ServerName)
	from SQLDBATools.[Staging].[CollectionErrors] e
		where e.CollectionTime >= DATEADD(hour,-2,getdate())
		and e.Cmdlet = 'Collect-VolumeInfo'
		order by e.CollectionTime desc
END

IF (@ServerNames IS NOT NULL)
BEGIN
	SET @subject = 'Wrapper-VolumeInfo - Failure';
	SET @p_recipients = 'SQLDBA@contso.com';

	SET @htmlBody = 'Hi DBA Team,
	<br><br>
	VolumeInfo data collection has failed for following servers:-
	<p>'+@ServerNames+'</p>

	Kindly take appropriate action. Below query can be used to find exact cmdlet to execute.
	<p>
select * from [Staging].[CollectionErrors] e<br>
		where e.CollectionTime >= DATEADD(hour,-2,getdate())<br>
		and e.Cmdlet = ''Collect-VolumeInfo''<br>
		--order by e.CollectionTime desc
</p><br>

	Regards,<br>
	SQL Alerts
';  

	EXEC msdb..sp_send_dbmail 
		@recipients = @p_recipients,  
		@subject = @subject,  
		@body = @htmlBody,  
		@body_format = 'HTML' ; 
END
