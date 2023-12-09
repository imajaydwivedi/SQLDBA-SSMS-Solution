use DBA
go

if object_id('dbo.usp_RemoveReplSchemaAccessContention') is null
	exec ('create procedure dbo.usp_RemoveReplSchemaAccessContention as select 1 as dummy;');
go

ALTER PROCEDURE dbo.usp_RemoveReplSchemaAccessContention @verbose bit = 0, @LogToTable bit = 0, @latency_threshold_minutes int = 20, @Job_Execution_Threshold_Minutes int = 10
WITH RECOMPILE 
AS
BEGIN
	SET NOCOUNT ON;
	--declare @verbose bit = 1; /* Change this to 0 */
	--declare @LogToTable bit = 0;
	--declare @latency_threshold_minutes int = 20;
	declare @is_latency_present bit = 1;
	declare @is_repl_schema_contention_present bit = 1; 
	declare @JobNames varchar(max);
	declare @JobName varchar(500);
	declare @JobName_lastStarted varchar(500);
	declare @Job_lastStarted_Time datetime2;
	--declare @Job_Execution_Threshold_Minutes int = 10;
	declare @is_job_not_runnning bit = 1;
	declare @currentTime smalldatetime = getdate();
	declare @startJob_bit bit = 0;
	declare @isJobStarted bit = 0;
	declare @performStopStartAction bit = 0;

	if @verbose = 1
		print 'Declaring tables/variables..';
	declare @tbl_replcounters table ([database] varchar(100),[replicated transactions] bigint,[replication rate trans/sec] bigint,[replication latency (sec)] bigint,[replbeginlsn] varbinary(100),[replnextlsn] varbinary(100));
	declare @tbl_Latency table (
		[publication] [varchar](200) NULL,
		[Publisher_Db => Subscriber_Db] [varchar](520) NULL,
		[Token_State] [varchar](7) NOT NULL,
		[current_Latency] bigint NULL,
		[publisher_commit] [datetime] NULL,
		[distributor_commit] [datetime] NULL,
		[last_token_latency (publisher_commit)] [varchar](150) NULL,
		[lastwaittype] [varchar](100) NULL,
		[Log_Reader_Agent_Job] [varchar](200) NULL,
		[replicated transactions] [bigint] NULL,
		[is_running] [bit] NULL
	)

	--select @LogToTable = case when @verbose = 1 then 0 else 1 end;

	while (@is_latency_present = 1 and @is_repl_schema_contention_present = 1) or @is_job_not_runnning = 1
	begin -- Loop
		if @verbose =1 
			print 'reset loop variables..';
		delete from @tbl_replcounters;
		delete from @tbl_Latency;
		set @JobNames = null;
		set @JobName = null;
		set @currentTime = getdate();
		set @startJob_bit = 0;
		set @isJobStarted = 0;
		set @performStopStartAction = 0;

		if @verbose =1 
			print 'Evaluating values of @is_latency_present & @is_repl_schema_contention_present';
		--if (select count(*) from DBA..vw_Repl_Latency_Details as l where l.current_Latency > @latency_threshold_minutes) >= 2
		begin try
			if exists (select * from DBA..vw_Repl_Latency_Details as l with (nolock) where l.current_Latency > @latency_threshold_minutes ) 
				set @is_latency_present = 1;
			else
				set @is_latency_present = 0;
		end try
		begin catch
			WAITFOR DELAY '00:02:00';
			continue;
		end catch

		if (select count(*) from sys.sysprocesses where program_name like 'Repl-LogReader%' and ltrim(rtrim(lastwaittype)) = 'REPL_SCHEMA_ACCESS') >= 2
			set @is_repl_schema_contention_present = 1;
		else
			set @is_repl_schema_contention_present = 0;

		if @verbose = 1
			print 'insert @tbl_replcounters';
		insert @tbl_replcounters
		exec sp_replcounters;

		--if @verbose = 1
		--	select * from @tbl_replcounters;

		if @verbose = 1
			print 'insert @tbl_Latency';
		begin try
			insert @tbl_Latency
			select l.publication, 
					case when p.publisher_db = l.subscriber_db then quotename(p.publisher_db) else QUOTENAME(p.publisher_db) + ' => '+ QUOTENAME(l.subscriber_db) end as [Publisher_Db => Subscriber_Db], 
					l.Token_State, l.current_Latency, l.publisher_commit, l.distributor_commit, --l.subscriber_commit,
					l.[last_token_latency (publisher_commit)], sp.lastwaittype, j.job_name as Log_Reader_Agent_Job, 
					c.[replicated transactions],
					j.is_running --,l.currentTime
			from DBA..vw_Repl_Latency_Details as l with (nolock)
			left join DistributorServer.distribution.dbo.MSpublications as p with (nolock)
				on p.publication = l.publication
			left join sys.sysprocesses as sp
				on db_name(sp.dbid) = p.publisher_db and sp.program_name like 'Repl-LogReader%' 
			left join DistributorServer.DBA.dbo.vw_ReplicationJobs as j with (nolock)
				on j.category_name = 'REPL-LogReader' and j.publisher_db = p.publisher_db
			left join @tbl_replcounters as c
				on c.[database] = p.publisher_db
			--order by c.[replicated transactions] desc
		end try
		begin catch
			WAITFOR DELAY '00:02:00';
			continue;
		end catch
	
		if @verbose = 1
			select *,[Current Time] = @currentTime from @tbl_Latency;

		if @verbose = 1
			print 'Evaluating value for @JobNames';
		select @JobNames = coalesce(@JobNames+','+Log_Reader_Agent_Job,Log_Reader_Agent_Job)
		from (	select distinct Log_Reader_Agent_Job
				from @tbl_Latency
				where ltrim(rtrim(lastwaittype)) = 'REPL_SCHEMA_ACCESS'
				--and current_Latency > @latency_threshold_minutes
				and [is_running] = 1
				and (	@JobName_lastStarted is null
						or @JobName_lastStarted <> Log_Reader_Agent_Job
						or (Log_Reader_Agent_Job = @JobName_lastStarted AND datediff(minute,@Job_lastStarted_Time,@currentTime) > @Job_Execution_Threshold_Minutes)
						or (Log_Reader_Agent_Job = @JobName_lastStarted AND current_Latency < @latency_threshold_minutes)
					)
			) as l
		--order by [replicated transactions] desc

		if exists (select * from @tbl_Latency where is_running = 0)
			set @is_job_not_runnning = 1;
		else
			set @is_job_not_runnning = 0;

		set @performStopStartAction = (case when @is_job_not_runnning = 1 or (@JobNames is not null and @is_latency_present = 1) then 1 else 0 end)

		if @verbose = 1
			select	[CodePortion] = 'Before Stop/Start Logic', 
					[@is_latency_present] = @is_latency_present, 
					[@is_repl_schema_contention_present] = @is_repl_schema_contention_present, 
					[@is_job_not_runnning] = @is_job_not_runnning, 
					[@JobNames] = @JobNames, 
					[@Job_Execution_Threshold_Minutes] = @Job_Execution_Threshold_Minutes, 
					[@JobName_lastStarted] = @JobName_lastStarted, 
					[@Job_lastStarted_Time] = @Job_lastStarted_Time,
					[Current Time] = @currentTime,
					[Stop/Start Block Logic] = (case when @performStopStartAction = 1 then 'True' else 'False' end);

		if @verbose = 1
			print 'Evaluating condition of [Stop/Start Block Logic], and populating DBA tables based on @LogToTable';
		if @LogToTable = 1 and @performStopStartAction = 1
		begin

			if @verbose = 1
				print 'insert dbo.repl_schema_access_Latency';
			insert dbo.repl_schema_access_Latency
			select *,[Current Time] = @currentTime from @tbl_Latency;

			if @verbose = 1
				print 'insert dbo.repl_schema_access_start_entry';
			insert dbo.repl_schema_access_start_entry
			select	[CodePortion] = 'Before Stop/Start Logic', 
					[@is_latency_present] = @is_latency_present, 
					[@is_repl_schema_contention_present] = @is_repl_schema_contention_present, 
					[@is_job_not_runnning] = @is_job_not_runnning, 
					[@JobNames] = @JobNames, 
					[@Job_Execution_Threshold_Minutes] = @Job_Execution_Threshold_Minutes, 
					[@JobName_lastStarted] = @JobName_lastStarted, 
					[@Job_lastStarted_Time] = @Job_lastStarted_Time,
					[Current Time] = @currentTime,
					[Stop/Start Block Logic] = (case when @performStopStartAction = 1 then 'True' else 'False' end);
		end

		if @performStopStartAction = 1
		begin -- [Stop/Start Block Logic]
			if @JobNames is not null
				exec DistributorServer.DBA.dbo.usp_ChangeJobRunningState @jobs = @JobNames, @state = 'Stop', @verbose = 0, @LogToTable = 1, @Source = 'usp_RemoveReplSchemaAccessContention';

			if @verbose = 1
				print 'Evaluating value of  @startJob_bit';
			if	(@is_job_not_runnning = 1 or @JobNames is not null)
				and 
				(	@Job_lastStarted_Time is null
					or @JobName_lastStarted is null
					or datediff(minute,@Job_lastStarted_Time,@currentTime) > @Job_Execution_Threshold_Minutes
					or exists (select * from @tbl_Latency where Log_Reader_Agent_Job = @JobName_lastStarted and current_Latency < @latency_threshold_minutes)
				)
			begin
				set @startJob_bit = 1
			end

			if @startJob_bit = 1
			begin
				if @verbose = 1
					print 'Inside @startJob_bit = 1, Evaluating value of @JobName';
				set @JobName = (select top 1 l.Log_Reader_Agent_Job from @tbl_Latency as l where ([is_running] = 0 or ltrim(rtrim(lastwaittype)) = 'REPL_SCHEMA_ACCESS') order by l.current_Latency desc);			
			
				--if @JobName_lastStarted is null or @JobName <> @JobName_lastStarted
				if @JobName is not null
				begin
					if @verbose = 1
					begin
						print '[Current Time] = ' + convert(nvarchar,@currentTime,120);
						print 'Executing usp_ChangeJobRunningState for @JobName = '+QUOTENAME(@JobName);
					end
					exec DistributorServer.DBA.dbo.usp_ChangeJobRunningState @jobs = @JobName, @state = 'Start', @verbose = @verbose, @LogToTable = 1, @Source = 'usp_RemoveReplSchemaAccessContention';
				
					set @isJobStarted = 1;
					set @JobName_lastStarted = @JobName;
					set @Job_lastStarted_Time = @currentTime;
				end
			end

			if @LogToTable = 1
			begin
				if @verbose = 1
					print 'insert dbo.repl_schema_access_end_entry';
				insert dbo.repl_schema_access_end_entry
					([CodePortion],[@JobName],[Stop-Job-Logic],[Start-Job-Logic (@startJob_bit)],[Is Job Started (@isJobStarted)],[Current Time])
				select	[CodePortion] = 'After Stop/Start Logic',
						[@JobName] = @JobName, 
						[Stop-Job-Logic] = case when @JobNames is not null then 'True' else 'False' end,
						[Start-Job-Logic (@startJob_bit)] = case when @startJob_bit = 1 then 'True' else 'False' end,
						[Is Job Started (@isJobStarted)] = case when @isJobStarted = 1 then 'True' else 'False' end,					
						[Current Time] = @currentTime;
				break;
			end
			--break;
		end -- [Stop/Start Block Logic]
		else 
		begin
			print 'No latency due to Repl_Schema_Access contention/Stopped job found for Replication'
			--BREAK;
		end

		if @verbose = 1
		begin
			print 'Display [After Stop/Start Logic] variable/parameter values';
			select	[CodePortion] = COALESCE(v.[CodePortion],n.[CodePortion]),
					[Stop-Job-Logic] = COALESCE(v.[Stop-Job-Logic],n.[Stop-Job-Logic]),
					[Start-Job-Logic (@startJob_bit)] = COALESCE(v.[Start-Job-Logic (@startJob_bit)],n.[Start-Job-Logic (@startJob_bit)]),
					[Is Job Started (@isJobStarted)] = COALESCE(v.[Is Job Started (@isJobStarted)],n.[Is Job Started (@isJobStarted)]),
					[@JobName] = COALESCE(v.[@JobName],n.[@JobName]),
					[Current Time] = COALESCE(v.[Current Time],n.[Current Time])
			from (
					select	[CodePortion] = 'After Stop/Start Logic',
							[@JobName] = @JobName, 
							[Stop-Job-Logic] = case when @JobNames is not null then 'True' else 'False' end,
							[Start-Job-Logic (@startJob_bit)] = case when @startJob_bit = 1 then 'True' else 'False' end,
							[Is Job Started (@isJobStarted)] = case when @isJobStarted = 1 then 'True' else 'False' end,					
							[Current Time] = CONVERT(varchar,@currentTime,120)
					) as v
			full outer join
				(
					select [CodePortion] = '--- END OF LOOP ---',
							[@JobName] = '--- END OF LOOP ---', 
							[Stop-Job-Logic] = '--- END OF LOOP ---',
							[Start-Job-Logic (@startJob_bit)] = '--- END OF LOOP ---',
							[Is Job Started (@isJobStarted)] = '--- END OF LOOP ---',
							[Current Time] = '--- END OF LOOP ---'
				) as n
			on n.CodePortion = v.CodePortion;
		end

		if @performStopStartAction = 1
			WAITFOR DELAY '00:02:00';
	end -- Loop
END
GO
/*
EXEC DBA.dbo.usp_RemoveReplSchemaAccessContention @verbose = 1, @LogToTable = 0,  @Job_Execution_Threshold_Minutes = 20
GO
*/