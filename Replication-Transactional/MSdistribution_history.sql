use distribution;

set nocount on;
declare @verbose bit = 0;

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
select @currentTime = GETDATE();
--select @currentTime = cast('2020-01-28 20:15:00.000' as datetime);
set @recepients = 'ajay.dwivedi@gmail.com; anant.dwivedi@gmail.com;';
set @agent_last_log_threshold_minutes = 20;

if @verbose = 1
	print 'Declaring cursor..';
DECLARE cursor_distributor_agent CURSOR LOCAL FAST_FORWARD FOR
	select a.name as agent_job_name, a.job_id as agent_job_id, p.name as publisher, s.name as subscriber, a.publisher_db, a.subscriber_db, a.publication
	from distribution.dbo.MSdistribution_agents as a 
	left join master.sys.servers as p on p.server_id = a.publisher_id
	left join master.sys.servers as s on s.server_id = a.subscriber_id
	where a.local_job = 1
	--and a.name = 'YourPublisherServer-Facebook-FacebookPublication-SubscriberServer-59';
	
OPEN cursor_distributor_agent;  
FETCH NEXT FROM cursor_distributor_agent INTO @agent_job_name, @agent_job_id, @publisher, @subscriber, @publisher_db, @subscriber_db, @publication;

WHILE @@FETCH_STATUS = 0  
BEGIN
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
		exec distribution..sp_MSstopdistribution_agent @publisher, @publisher_db, @publication, @subscriber, @subscriber_db;
		--
		WAITFOR DELAY '00:00:05'; -- 5 Seconds
		--
		--To START the Distribution Agent:
		exec distribution..sp_MSstartdistribution_agent @publisher, @publisher_db, @publication, @subscriber, @subscriber_db;

		set @mailSubject = 'Distribution Agent - '+QUOTENAME(@agent_job_name)+' restarted';
		set @mailBody = 'Distribution Agent job '+QUOTENAME(@agent_job_name)+' restarted has been restarted as it did not log any messages in last '+cast(@agent_last_log_threshold_minutes as varchar(20))+' minutes.';
		EXEC msdb.dbo.sp_send_dbmail  
			--@profile_name = 'Adventure Works Administrator',  
			@recipients = @recepients,  
			@body = @mailBody,  
			@subject = @mailSubject ;  
	end

	FETCH NEXT FROM cursor_distributor_agent INTO @agent_job_name, @agent_job_id, @publisher, @subscriber, @publisher_db, @subscriber_db, @publication;
END

CLOSE cursor_distributor_agent;  
DEALLOCATE cursor_distributor_agent;  