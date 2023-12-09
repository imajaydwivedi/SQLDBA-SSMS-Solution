use distribution;

set nocount on;
declare @verbose bit = 1;

if @verbose = 1
	print 'Declaring local variables..';
declare @currentTime datetime;
declare @recepients varchar(2000);
declare @mailBody varchar(4000);
declare @mailSubject varchar(500);
declare @agent_job_name varchar(500);
declare @agent_job_id varbinary(16);
declare @publisher varchar(200);
declare @subscriber varchar(200);
declare @publisher_db varchar(200);
declare @subscriber_db varchar(200);
declare @publication varchar(500);
declare @agent_start_time datetime;
declare @agent_last_log_time datetime;
declare @agent_last_log_threshold_minutes int;
declare @agent_restart_state int;
select @currentTime = GETDATE();
set @agent_restart_state = 0;
--select @currentTime = cast('2020-01-28 20:15:00.000' as datetime);
set @recepients = 'ajay.dwivedi@contso.com;anant.dwivedi@contso.com';
set @agent_last_log_threshold_minutes = 15;

if @verbose = 1
	print 'Declaring cursor..';
DECLARE cursor_distributor_agent CURSOR LOCAL FAST_FORWARD FOR
	select a.name as agent_job_name, a.job_id as agent_job_id, p.name as publisher, s.name as subscriber, a.publisher_db, a.subscriber_db, a.publication
	from distribution.dbo.MSdistribution_agents as a 
	left join master.sys.servers as p on p.server_id = a.publisher_id
	left join master.sys.servers as s on s.server_id = a.subscriber_id
	where a.local_job = 1
	
OPEN cursor_distributor_agent;  
FETCH NEXT FROM cursor_distributor_agent INTO @agent_job_name, @agent_job_id, @publisher, @subscriber, @publisher_db, @subscriber_db, @publication;

WHILE @@FETCH_STATUS = 0  
BEGIN
	set @agent_restart_state = 0;
	set @mailBody = null;
	set @mailSubject = null;

	if @verbose = 1
		print 'Evaluating variables for distribution agent job '''+@agent_job_name+'''';

	select @agent_start_time = case when max(h.time) is not null then max(h.time) else DATEADD(hour,-48,getdate()) end
	from distribution.dbo.MSdistribution_history as h
	left join distribution.dbo.MSdistribution_agents as a on a.id = h.agent_id	
	where a.name = @agent_job_name
	and h.runstatus = 1; -- Start
	--and h.comments in ('Starting agent.');

	select @agent_last_log_time = case when max(h.time) is not null then max(h.time) else @agent_start_time end
	from distribution.dbo.MSdistribution_history as h
	left join distribution.dbo.MSdistribution_agents as a on a.id = h.agent_id	
	where a.name = @agent_job_name
	and h.time >= @agent_start_time
	and h.runstatus = 3; -- In Progress
	--and h.comments not in ('Starting agent.','Initializing')

	if @verbose = 1 
	begin
		if DATEDIFF(MINUTE,@agent_last_log_time,@currentTime) > @agent_last_log_threshold_minutes
		begin
			select @currentTime as [@currentTime], @agent_job_name as [@agent_job_name], @agent_start_time as [@agent_start_time], @agent_last_log_time as [@agent_last_log_time];

			print 'ISSUE';
		end
		else
			print 'no issue';
	end

	/*
	select getdate() as currentTime, a.name as agent_job_name, a.publication, a.subscriber_db, a.job_id, h.runstatus, h.start_time, h.time as agent_log_time, h.comments
	from distribution.dbo.MSdistribution_history as h
	left join MSdistribution_agents as a on a.id = h.agent_id	
	where a.name = @agent_job_name
	and h.time >= @agent_start_time
	and h.runstatus = 3 -- In Progress
	order by agent_log_time desc;
	*/

	if DATEDIFF(MINUTE,@agent_last_log_time,@currentTime) > @agent_last_log_threshold_minutes
	begin
		print 'Distribution Agent - Start /Stop in T-SQL';
		
		-- To STOP the Distribution Agent:
		BEGIN TRY
			IF DBA.dbo.fn_IsJobRunning(@agent_job_name) = 1
			begin
				exec distribution..sp_MSstopdistribution_agent @publisher, @publisher_db, @publication, @subscriber, @subscriber_db;
				set @agent_restart_state += 1;
			end
		END TRY
		BEGIN CATCH
			PRINT  'ERROR => '+CHAR(10)+
					CHAR(9)+'ErrorNumber => '+CAST(ERROR_NUMBER() AS VARCHAR(20))+CHAR(10)+
					CHAR(9)+'ErrorSeverity => '+CAST(ERROR_SEVERITY() AS VARCHAR(20)) +CHAR(10)+
					CHAR(9)+'ErrorState => '+CAST(ERROR_STATE() AS VARCHAR(20)) + CHAR(10)+
					CHAR(9)+'ErrorLine => '+ISNULL(ERROR_LINE(),'') +CHAR(10)+
					CHAR(9)+'ErrorProcedure => '+ISNULL(ERROR_PROCEDURE(),'')+CHAR(10)+
					CHAR(9)+'ErrorMessage => '+ISNULL(ERROR_MESSAGE(),'')+CHAR(10);
		END CATCH
		--
		WHILE(DBA.dbo.fn_IsJobRunning(@agent_job_name) = 1)
		BEGIN
			WAITFOR DELAY '00:00:02'; -- 5 Seconds
		END
		--
		--To START the Distribution Agent:
		BEGIN TRY
			IF DBA.dbo.fn_IsJobRunning(@agent_job_name) = 0
			begin
				exec distribution..sp_MSstartdistribution_agent @publisher, @publisher_db, @publication, @subscriber, @subscriber_db;
				set @agent_restart_state += 2;
			end
		END TRY
		BEGIN CATCH
			PRINT  'ERROR => '+CHAR(10)+
					CHAR(9)+'ErrorNumber => '+CAST(ERROR_NUMBER() AS VARCHAR(20))+CHAR(10)+
					CHAR(9)+'ErrorSeverity => '+CAST(ERROR_SEVERITY() AS VARCHAR(20)) +CHAR(10)+
					CHAR(9)+'ErrorState => '+CAST(ERROR_STATE() AS VARCHAR(20)) + CHAR(10)+
					CHAR(9)+'ErrorLine => '+ISNULL(ERROR_LINE(),'') +CHAR(10)+
					CHAR(9)+'ErrorProcedure => '+ISNULL(ERROR_PROCEDURE(),'')+CHAR(10)+
					CHAR(9)+'ErrorMessage => '+ISNULL(ERROR_MESSAGE(),'')+CHAR(10);
		END CATCH

		set @mailSubject = 'Replication Agent - '+QUOTENAME(@agent_job_name)+' restarted';
		set @mailBody = '<h1>Replication Agent job '+QUOTENAME(@agent_job_name)+' restarted.</h1>'+
						'<h3>Following agent job has not logged an update in the last '+cast(@agent_last_log_threshold_minutes as varchar(20))+' minutes.</h3>'+
						'<p><table border=1><tr><th>Publisher</th><th>Subscriber</th><th>Publication</th><th>Subscriber Db</th><th>Agent Job Name</th></tr>'+
						'<tr><td>'+@publisher+'</td><td>'+@subscriber+'</td><td>'+@publication+'</td><td>'+@subscriber_db+'</td><td>'+@agent_job_name+'</td></tr>'+
						'</table></p>'+

						'<p>In order to resolve this, the replication agent job was '+(case when @agent_restart_state = 2 then 'started' else 'restarted' end)+'. <br>If this alert is received again and again, kindly look into this issue.<br></p> '+
						'<p><br>Thanks & Regards,<br>
SQL Alerts<br>
DBA@contso.com<br>
-- Alert Coming from SQL Agent Job [DBA - Replication Agent Check]<br></p>'

		if @verbose = 1
		begin
			print	'!~~~~~~~~~~ HTML Body ~~~~~~~~~~!'+char(10)+char(10)+@mailbody;
		end

		IF @agent_restart_state > 0
			EXEC msdb.dbo.sp_send_dbmail
				@recipients = @recepients,  
				@subject = @mailSubject,
				@body = @mailBody,
				@body_format = 'HTML';
	end

	FETCH NEXT FROM cursor_distributor_agent INTO @agent_job_name, @agent_job_id, @publisher, @subscriber, @publisher_db, @subscriber_db, @publication;
END

CLOSE cursor_distributor_agent;  
DEALLOCATE cursor_distributor_agent;
