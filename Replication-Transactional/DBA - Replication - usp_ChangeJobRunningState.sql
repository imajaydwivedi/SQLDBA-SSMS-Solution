use DBA
go

if object_id('dbo.usp_ChangeJobRunningState') is null
	exec ('create procedure dbo.usp_ChangeJobRunningState as select 1 as dummy;');
go

alter procedure dbo.usp_ChangeJobRunningState @jobs varchar(max), @state varchar(30), @verbose bit = 0, @LogToTable bit = 0, @Source varchar(200)= 'Manual'
as
begin
	/*	Created By:			Ajay Dwivedi
		Created Date:		13-Mar-2020
		Version:			0.0
		Purpose:			Start/Stop/Restart SQL Agent Jobs using this procedure
	*/
	set nocount on;
	declare @_job_name varchar(500);
	declare @_IsJobRunning bit = 0;
	declare @_AreValidParameters bit = 1;
	declare @_tbl_jobs table (job_name varchar(500), is_processed bit default 0);

	if OBJECT_ID('dbo.JobRunningStateChangeLog') is null
		create table dbo.JobRunningStateChangeLog  (CollectionTime datetime2 not null default getdate(), JobName varchar(500) not null, State varchar(30) not null, Source varchar(200) default 'Manual');

	if @verbose = 1
	begin
		print '@jobs = '''+@jobs+'''';
		print '@state = '''+@state+'''';
	end

	-- Check is specific databases have been mentioned
	if(@Verbose = 1)
			PRINT 'Populating table @_tbl_jobs';
	IF @jobs is not null
	BEGIN
		WITH t1(job_name,jobs) AS 
		(
			SELECT	CAST(LEFT(@jobs, CHARINDEX(',',@jobs+',')-1) AS VARCHAR(500)) as job_name,
					STUFF(@jobs, 1, CHARINDEX(',',@jobs+','), '') as jobs
			--
			UNION ALL
			--
			SELECT	CAST(LEFT(jobs, CHARINDEX(',',jobs+',')-1) AS VARChAR(500)) AS job_name,
					STUFF(jobs, 1, CHARINDEX(',',jobs+','), '')  as jobs
			FROM t1
			WHERE jobs > ''	
		)
		INSERT @_tbl_jobs (job_name)
		SELECT LTRIM(RTRIM(job_name)) FROM t1
		OPTION (MAXRECURSION 32000);
	END

	IF(@Verbose = 1)
	BEGIN
		PRINT 'SELECT * FROM @_tbl_jobs;';
		SELECT *, @state as [Desired_State] FROM @_tbl_jobs;
	END

	while exists (select * from @_tbl_jobs where is_processed = 0)
	begin -- Loop through each job
		
		select @_job_name = min(job_name) from @_tbl_jobs where is_processed = 0;
		select @_IsJobRunning = DBA.dbo.fn_IsJobRunning(@_job_name);

		if @verbose = 1
			print '@_IsJobRunning = '+cast(@_IsJobRunning as varchar);

		if @_IsJobRunning = 1 and @state = 'Start'
			set @_AreValidParameters = 0;
		if @_IsJobRunning = 0 and @state = 'Stop'
			set @_AreValidParameters = 0;

		if @_AreValidParameters = 1
		begin
			if @state = 'Stop' or (@state = 'Restart' and @_IsJobRunning = 1)
			begin
				exec msdb..sp_stop_job @job_name = @_job_name;
				insert dbo.JobRunningStateChangeLog (JobName, State, Source)
				select @_job_name as JobName, 'Stop' as State, @Source as Source;
			end
			if @state = 'Start' or (@state = 'Restart' and @_IsJobRunning = 0)
			begin
				exec msdb..sp_start_job @job_name = @_job_name;
				insert dbo.JobRunningStateChangeLog (JobName, State, Source)
				select @_job_name as JobName, 'Start' as State, @Source as Source;
			end
		
			if @verbose = 1
				print char(13)+'Job ['+@_job_name+'] has been set to '''+@state+''' state.'
		end
		else
		begin
			print char(13)+'Incompatiable Parameters provided.'
		end
		print '--	--------------------------------------------------------'+char(13)+char(13)

		update @_tbl_jobs set is_processed = 1 where job_name = @_job_name;
	end -- Loop through each job
end
go

/*
exec DBA.dbo.usp_ChangeJobRunningState @jobs = 'Job1, Job2', @state = 'Stop', @verbose = 1;
go

exec DBA.dbo.usp_ChangeJobRunningState @jobs = 'Job1', @state = 'Start', @verbose = 1, @LogToTable = 1, @Source = 'usp_RemoveReplSchemaAccessContention';
go

*/