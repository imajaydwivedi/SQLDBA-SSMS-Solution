set nocount on;

declare @result int; 
if object_id('tempdb..#output') is not null
	drop table #output;
create table #output (id int identity(1,1), output varchar(2000));
declare @body varchar(max);
declare @iscollectorstarted bit = 0;

-- check status
insert #output
exec @result = xp_cmdshell 'logman query SQLDBA' -- W:\PerfMon
	
if not exists (select * from #output where output like 'Status:%Running')
begin
	truncate table #output;
	-- start data collector
	insert #output
	exec @result = xp_cmdshell 'logman start SQLDBA' -- W:\PerfMon
	if (@result = 0)  
		set @iscollectorstarted = 1;
end
	
	--select @result as [@result];
	--delete from #output where output is null;
	--select * from #output where output like 'Status:%Running'
	--select * from #output --where output in ('The command completed successfully.','The operator or administrator has refused the request.')
	
	SET @body = '<h3>SQLDBA Data Collector has been started</h3><br>
<p><br>
Thanks & Regards,<br>
SQLAlerts <br>
-- Alert coming from job [DBA - Start DataCollector]<br>
';

	if @iscollectorstarted = 1
	begin

		EXEC msdb.dbo.sp_send_dbmail
								@recipients = 'sqlagentservice@gmail.com;',  
								@subject = 'SQLDBA Data Collector Started',  
								@body_format = 'HTML',
								@body = @body;
	end
