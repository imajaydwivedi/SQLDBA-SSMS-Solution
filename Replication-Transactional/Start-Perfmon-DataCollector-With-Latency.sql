set nocount on;
declare @threshold_in_minutes int = 60;
declare @threshold_no_of_publications int = 5;
if(select count(*) as counts from DBA.dbo.vw_Repl_Latency where Latest_Latency >= @threshold_in_minutes) >= @threshold_no_of_publications
begin -- If latency exists
	declare @result int; 
	if object_id('tempdb..#output') is not null
		drop table #output;
	create table #output (id int identity(1,1), output varchar(2000));
	declare @body varchar(max);
	declare @iscollectorstarted_middleman bit = 0;
	declare @iscollectorstarted_distributor bit = 0;

	IF 1=1
	BEGIN -- Middleman MiddleManServer
		-- check status
		insert #output
		exec @result = xp_cmdshell 'logman query SQLDBA -s MiddleManServer' -- \\MiddleManServer\J$\PerfMon
	
		if not exists (select * from #output where output like 'Status:%Running')
		begin
			truncate table #output;
			-- start data collector
			insert #output
			exec @result = xp_cmdshell 'logman start SQLDBA -S MiddleManServer' -- \\MiddleManServer\J$\PerfMon
			if (@result = 0)  
			   set @iscollectorstarted_middleman = 1;
		end
	END -- Middleman MiddleManServer

	IF 1=1
	BEGIN -- Distributor DistributorServer
		truncate table #output;
		-- check status
		insert #output
		exec @result = xp_cmdshell 'logman query SQLDBA -s DistributorServer' -- \\DistributorServer\Q$\PerfMon
	
		if not exists (select * from #output where output like 'Status:%Running')
		begin
			truncate table #output;
			-- start data collector
			insert #output
			exec @result = xp_cmdshell 'logman start SQLDBA -S DistributorServer' -- \\DistributorServer\Q$\PerfMon
			if (@result = 0)  
			   set @iscollectorstarted_distributor = 1;
		end
	END -- Distributor DistributorServer
	
	--select @result as [@result];
	--delete from #output where output is null;
	--select * from #output where output like 'Status:%Running'
	--select * from #output --where output in ('The command completed successfully.','The operator or administrator has refused the request.')
	
	SET @body = '<style>  
  .attention_yes {  
   background-color: yellow;  
   color: #A52A2A;  
  }  
  .attention_no {  
   color: #228B22;  
  }  
  </style>

<h2>Replication latency of more than '+cast(@threshold_in_minutes as varchar(10))+' minutes exists for '+cast(@threshold_no_of_publications as varchar(10))+' or more publications</h2>
'+(case when @iscollectorstarted_distributor = 1 then '<h4>Perfmon data collector [SQLDBA] has been started on DistributorServer.</h4>' else '' end)+'
'+(case when @iscollectorstarted_middleman = 1 then '<h4>Perfmon data collector [SQLDBA] has been started on MiddleManServer.</h4>' else '' end);

	SET @body += '<p><table border="1"> 
<tr><th>Publication</th><th>current Time</th><th>Token Insertion Time</th><th>Latency(minutes)</th><th>Token_State</th></tr>' +    
   CAST ( ( SELECT td = publication,       '',    
       td = cast(currentTime as varchar(30)), '',   
       td = cast(publisher_commit as varchar(30)), '',    
       td = cast(Latest_Latency as varchar(10)), '',  
       td = Token_State  
       FROM DBA..vw_Repl_Latency
	   WHERE Latest_Latency >= @threshold_in_minutes
       ORDER BY publication ASC  
       FOR XML PATH('tr'), TYPE     
   ) AS NVARCHAR(MAX) ) +    
'</table></p>' ;

	SET @body += '
<p><br>
Thanks & Regards,<br>
SQLAlerts <br>
-- Alert coming from job [DBA - Replication  - Start DataCollector]<br>
';

	if @iscollectorstarted_distributor = 1 or @iscollectorstarted_middleman = 1
	begin

		EXEC msdb.dbo.sp_send_dbmail
								@recipients = 'sqlagentservice@gmail.com;',  
								@subject = 'Replication Latency - Perfmon Started',  
								@body_format = 'HTML',
								@body = @body;
	end

end -- If latency exists