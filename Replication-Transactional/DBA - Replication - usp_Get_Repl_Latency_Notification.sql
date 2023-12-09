USE [DBA]
GO
	
IF OBJECT_ID('dbo.usp_Get_Repl_Latency_Notification') IS NULL
	EXEC ('CREATE PROCEDURE dbo.usp_Get_Repl_Latency_Notification AS SELECT 1 as Dummy');
GO
ALTER PROCEDURE [dbo].[usp_Get_Repl_Latency_Notification] 
	@recipients VARCHAR(2000) = 'ajay.dwivedi@gmail.com', @threshold_minutes int = 40, @verbose bit = 0
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @tableHTML  NVARCHAR(MAX) ;  
	DECLARE @mailSubject VARCHAR(500);
	DECLARE @oldest_publisher_commit DATETIME;
 
	if exists (select * from DBA..vw_Repl_Latency where Latest_Latency >= @threshold_minutes)
	begin
		SET @oldest_publisher_commit = (select min(publisher_commit) as oldest_publisher_commit from DBA..vw_Repl_Latency where @threshold_minutes >= @threshold_minutes);

		if @verbose = 1
			select @oldest_publisher_commit as [@oldest_publisher_commit];

		-- If replication latency is found, then check for any errors in distribution history		
		if object_id('tempdb..#MSdistribution_history_Errors') is not null
			drop table #MSdistribution_history_Errors;
		select a.publication, s.name as subscriber, a.subscriber_db, MAX(h.time) as agent_log_time, MAX(h.error_id) AS error_id, h.comments
		into #MSdistribution_history_Errors
		from DistibutorServer.distribution.dbo.MSdistribution_history h
		join DistibutorServer.distribution.dbo.MSdistribution_agents as a on h.agent_id = a.id
		join DistibutorServer.master.sys.servers as p on p.server_id = a.publisher_id
		join DistibutorServer.master.sys.servers as s on s.server_id = a.subscriber_id
		where error_id <> 0 and time >= @oldest_publisher_commit
		and (case when comments like 'Skipped % error(s) when applying transactions at the Subscriber.' then 0 else 1 end) = 1
		group by a.publication, s.name, a.subscriber_db, h.comments;

		if @verbose = 1
		begin			
			if not exists (select * from #MSdistribution_history_Errors)
				print 'No error logs found in distribution.dbo.MSdistribution_history since '+cast(@oldest_publisher_commit as varchar(30))+'.';
			else
				select '#MSdistribution_history_Errors' as Running_Query, * from #MSdistribution_history_Errors;
		end

		if @verbose = 1
			SELECT 'DBA..vw_Repl_Latency' as RunningQuery, * FROM DBA..vw_Repl_Latency ORDER BY publication ASC;

		SET @mailSubject = 'Replication Latency Report - '+@@SERVERNAME+' - '+CAST(GETDATE() AS VARCHAR(30));
		SET @tableHTML =  
		N'<style>
		.attention_yes {
			background-color: yellow;
			color: #A52A2A;
		}
		.attention_no {
			color: #228B22;
		}
		</style>'+
			N'<H1>Replication Latency Report</H1>' +  
			N'<h3>One or more publication has latency of more than '+cast(@threshold_minutes as varchar(10))+' minutes.</h3>'+
			N'<p><table border="1">' +  
			N'<tr><th>Publication</th> <th>Token State</th>	<th>Current Latency<br>(minutes)</th>	<th>Publisher<br>Commit</th>	<th>Distributor<br>Commit</th>
				  <th>Last Token Latency<br>(Publisher Commit)</th>	<th>LastWaitType</th>	<th>Current Time</th></tr>' +  

			CAST ( ( select td = l.publication,		'',
							td = l.Token_State,		'',
							td = cast(l.current_Latency as varchar(10)),	'', 
							td = isnull(convert(varchar,l.publisher_commit,120),' '),	'',
							td = isnull(convert(varchar,l.distributor_commit,120),' '),	'',
							td = isnull(l.[last_token_latency (publisher_commit)],' '),	'',
							td = isnull(rtrim(sp.lastwaittype),' '),	'',
							td = convert(varchar,getdate(),120)
					from DBA..vw_Repl_Latency_Details as l 
					left join DistibutorServer.distribution.dbo.MSpublications as p with (nolock)
						on p.publication = l.publication
					left join sys.sysprocesses as sp
						on db_name(sp.dbid) = p.publisher_db and sp.program_name like 'Repl-LogReader%' 
					left join DistibutorServer.DBA.dbo.vw_ReplicationJobs as j
						on j.category_name = 'REPL-LogReader' and j.publisher_db = p.publisher_db
					order by l.publication asc
					FOR XML PATH('tr'), TYPE
			) AS NVARCHAR(MAX) ) +  

			--CAST ( ( SELECT td = publication,       '',  
			--				td = cast(currentTime as varchar(30)), '', 
			--				td = cast(publisher_commit as varchar(30)), '',  
			--				td = cast(Latest_Latency as varchar(10)), '',
			--				td = Token_State
			--		  FROM DBA..vw_Repl_Latency
			--		  ORDER BY publication ASC
			--		  FOR XML PATH('tr'), TYPE   
			--) AS NVARCHAR(MAX) ) +  


			N'</table></p>' ;

		if @verbose = 1
			print char(10)+@tableHTML+char(10);

		if exists (select * from #MSdistribution_history_Errors)
		begin
			SET @tableHTML = @tableHTML +
			N'<h4>Below errors have been logged by agents since last pending tracer token.</h4>'+
			N'<p><table border="1">' +  
				N'<tr><th>Publication</th><th>Subscriber</th><th>Subscriber Database</th><th>Agent Log Time</th><th>Error Id</th><th>Comments</th></tr>' +  
				CAST ( ( SELECT td = publication,       '',  
								td = subscriber, '', 
								td = subscriber_db, '',  
								td = cast(agent_log_time as varchar(30)), '',
								td = cast(error_id as varchar(30)), '',
								td = comments
						  FROM #MSdistribution_history_Errors
						  ORDER BY agent_log_time DESC
						  FOR XML PATH('tr'), TYPE   
				) AS NVARCHAR(MAX) ) +  
				N'</table></p>
	';

			if (select case when datepart(hour,getdate()) between 9 and 18 then 0 when datepart(hour,getdate()) in (22,23,0,1,2,3,4,5,6) then 0 else 1 end) = 1
			begin
				set @recipients = @recipients + (case when right(ltrim(rtrim(@recipients)),1) = ';' then '' else ';' end) +'noc-staff@contso.com;'
				SET @tableHTML = @tableHTML + '<p><br>
Hi NOC Team,<br><br>
Kindly call onCall SQLDBA to look into this replication issue.<br>
		
'
			end
		end

		SET @tableHTML = @tableHTML + '
<p><br>
Thanks & Regards,<br>
SQL Alerts<br>
DBA@contso.com<br>
-- Alert from job [DBA - Replication  - Latency Notification]<br>
</p>
'
  
		EXEC msdb.dbo.sp_send_dbmail @recipients=@recipients,
			@subject = @mailSubject,  
			@body = @tableHTML,  
			@body_format = 'HTML' ;  
	end
	else
	begin
		if @verbose = 1
			print 'No Latency found greator than '+cast(@threshold_minutes as varchar(10))+' minutes'
	end
END
GO


--	exec [dbo].[usp_Get_Repl_Latency_Notification] @threshold_minutes = 0, @VERBOSE = 1
