USE DBA;
GO

IF OBJECT_ID('dbo.usp_StopLongRunningJob') IS NULL
	EXECUTE ('CREATE PROCEDURE dbo.usp_StopLongRunningJob AS SELECT 1 as DummyCode;');
GO

-- EXEC dbo.usp_StopLongRunningJob @p_JobName = '(dba) Run-WaitStats', @p_TimeLimit_Minutes = 180

ALTER PROCEDURE [dbo].[usp_StopLongRunningJob] @p_JobName VARCHAR(125), @p_TimeLimit_Minutes INT = 180, @p_ForceJobStop BIT = 1 , @p_recipients VARCHAR(1000) = 'DBA@contso.com', @p_cc VARCHAR(1000) = NULL
AS
BEGIN
	/*	Created By:			Ajay Dwivedi
		Version:			0.0
		Modification:		May 12, 2019 - First Check in of code
	*/

	SET NOCOUNT ON;
	SET ANSI_WARNINGS OFF;

	DECLARE @_mailSubject VARCHAR(125);
	DECLARE @_mailBody VARCHAR(2000);


	--	Delete entries older than 7 days
	IF OBJECT_ID('DBA..whatIsRunning') IS NOT NULL
	BEGIN
		DELETE DBA..whatIsRunning WHERE [Source] = ('DBA Check ' + @p_JobName) AND [CollectionTime] <= DATEADD(day,-7,GETDATE());
	END

	--	Check if @p_JobName is running for more than @p_TimeLimit_Minutes
	IF EXISTS (
				SELECT *
				FROM msdb.dbo.sysjobactivity ja 
				LEFT JOIN msdb.dbo.sysjobhistory jh 
					ON ja.job_history_id = jh.instance_id
				JOIN msdb.dbo.sysjobs j 
				ON ja.job_id = j.job_id
				JOIN msdb.dbo.sysjobsteps js
					ON ja.job_id = js.job_id
					AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
				WHERE ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
				AND start_execution_date is not null
				AND stop_execution_date is null
				AND LTRIM(RTRIM(j.name)) = @p_JobName
				AND DATEDIFF(MINUTE,ja.start_execution_date,GETDATE()) >= @p_TimeLimit_Minutes
		)
	BEGIN
		BEGIN TRY
			--SELECT * FROM DBA..whatIsRunning;
			INSERT DBA..whatIsRunning
			(	session_id, DBName, percent_complete, session_status, request_status, running_command, request_wait_type, request_wait_resource, request_start_time, request_running_time, est_time_to_go, est_completion_time, [blocked by], statement_text, Batch_Text, [WaitTime(S)], [total_elapsed_time(S)], login_time, host_name, host_process_id, client_interface_name, login_name, memory_usage, session_writes, request_writes, session_logical_reads, request_logical_reads, is_user_process, session_row_count, request_row_count, sql_handle, plan_handle, open_transaction_count, request_cpu_time, granted_query_memory, query_hash, query_plan_hash, BatchQueryPlan, SqlQueryPlan, program_name, IsSqlJob, Source, CollectionTime
			)
			--	Query to find what's is running on server
			SELECT	session_id, DBName, percent_complete, session_status, request_status, running_command, request_wait_type, request_wait_resource, request_start_time, request_running_time, est_time_to_go, est_completion_time, [blocked by], statement_text, Batch_Text, [WaitTime(S)], [total_elapsed_time(S)], login_time, host_name, host_process_id, client_interface_name, login_name, memory_usage, session_writes, request_writes, session_logical_reads, request_logical_reads, is_user_process, session_row_count, request_row_count, sql_handle, plan_handle, open_transaction_count, request_cpu_time, granted_query_memory, query_hash, query_plan_hash, 
			[BatchQueryPlan] = bqp.query_plan, [SqlQueryPlan] = CAST(sqp.query_plan AS xml), 
			program_name, IsSqlJob, Source, CollectionTime
			FROM  (
					SELECT	s.session_id, 
							DB_NAME(r.database_id) as DBName,
							r.percent_complete,
							[session_status] = s.status,
							[request_status] = r.status,
							[running_command] = r.command,
							[request_wait_type] = r.wait_type, 
							[request_wait_resource] = wait_resource,
							[request_start_time] = r.start_time,
							[request_running_time] = CAST(((DATEDIFF(s,r.start_time,GetDate()))/3600) as varchar) + ' hour(s), '
								+ CAST((DATEDIFF(s,r.start_time,GetDate())%3600)/60 as varchar) + 'min, '
								+ CAST((DATEDIFF(s,r.start_time,GetDate())%60) as varchar) + ' sec',
							[est_time_to_go] = CAST((r.estimated_completion_time/3600000) as varchar) + ' hour(s), '
											+ CAST((r.estimated_completion_time %3600000)/60000  as varchar) + 'min, '
											+ CAST((r.estimated_completion_time %60000)/1000  as varchar) + ' sec',
							[est_completion_time] = dateadd(second,r.estimated_completion_time/1000, getdate()),
							[blocked by] = r.blocking_session_id,
							[statement_text] = Substring(st.TEXT, (r.statement_start_offset / 2) + 1, (
									(
										CASE r.statement_end_offset
											WHEN - 1
												THEN Datalength(st.TEXT)
											ELSE r.statement_end_offset
											END - r.statement_start_offset
										) / 2
									) + 1),
							[Batch_Text] = st.text,
							[WaitTime(S)] = r.wait_time / (1000.0),
							[total_elapsed_time(S)] = r.total_elapsed_time / (1000.0),
							s.login_time, s.host_name, s.host_process_id, s.client_interface_name, s.login_name, 
							s.memory_usage, 
							[session_writes] = s.writes, 
							[request_writes] = r.writes, 
							[session_logical_reads] = s.logical_reads, 
							[request_logical_reads] = r.logical_reads, 
							s.is_user_process, 
							[session_row_count] = s.row_count,
							[request_row_count] = r.row_count,
							r.sql_handle, 
							r.plan_handle, 
							r.open_transaction_count,
							[request_cpu_time] = r.cpu_time,
							[granted_query_memory] = CASE WHEN ((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024/1024) >= 1.0
														  THEN CAST(((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024/1024) AS VARCHAR(23)) + ' GB'
														  WHEN ((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024) >= 1.0
														  THEN CAST(((CAST(r.granted_query_memory AS numeric(20,2))*8)/1024) AS VARCHAR(23)) + ' MB'
														  ELSE CAST((CAST(r.granted_query_memory AS numeric(20,2))*8) AS VARCHAR(23)) + ' KB'
														  END,
							r.query_hash, 
							r.query_plan_hash,
							r.statement_start_offset, 
							r.statement_end_offset,
							[program_name] = CASE	WHEN	s.program_name like 'SQLAgent - TSQL JobStep %'
									THEN	(	select	top 1 'SQL Job = '+j.name 
												from msdb.dbo.sysjobs (nolock) as j
												inner join msdb.dbo.sysjobsteps (nolock) AS js on j.job_id=js.job_id
												where right(cast(js.job_id as nvarchar(50)),10) = RIGHT(substring(s.program_name,30,34),10) 
											)
									ELSE	s.program_name
									END,
							[IsSqlJob] = CASE WHEN s.program_name like 'SQLAgent - TSQL JobStep %'THEN 1 ELSE 2	END
							,[Source] = ('DBA Check ' + @p_JobName)
							,[CollectionTime] = GETDATE()
					FROM	sys.dm_exec_sessions AS s
					LEFT JOIN sys.dm_exec_requests AS r ON r.session_id = s.session_id
					OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
					WHERE	(case	when s.session_id != @@SPID
							AND	(	(	s.session_id > 50
									AND	(	r.session_id IS NOT NULL -- either some part of session has active request
										OR	ISNULL(open_resultset_count,0) > 0 -- some result is open
										)
									)
									OR	s.session_id IN (select ri.blocking_session_id from sys.dm_exec_requests as ri )
								) -- either take user sid, or system sid blocking user sid
									then 1
									when NOT (s.session_id != @@SPID
							AND	(	(	s.session_id > 50
									AND	(	r.session_id IS NOT NULL -- either some part of session has active request
										OR	ISNULL(open_resultset_count,0) > 0 -- some result is open
										)
									)
									OR	s.session_id IN (select ri.blocking_session_id from sys.dm_exec_requests as ri )
								))
									THEN 0
									else null
									end) = 1
					AND	(CASE	WHEN	s.program_name like 'SQLAgent - TSQL JobStep %'
								THEN	(	select	top 1 j.name 
											from msdb.dbo.sysjobs (nolock) as j
											inner join msdb.dbo.sysjobsteps (nolock) AS js on j.job_id=js.job_id
											where right(cast(js.job_id as nvarchar(50)),10) = RIGHT(substring(s.program_name,30,34),10) 
										)
								ELSE	s.program_name
								END) = @p_JobName
						) AS T			
			OUTER APPLY sys.dm_exec_query_plan(plan_handle) AS bqp
			OUTER APPLY sys.dm_exec_text_query_plan(plan_handle,statement_start_offset, statement_end_offset) as sqp;

			PRINT	'Entry of Job session details made into table DBA..whatIsRunning'
		END TRY
		BEGIN CATCH
			PRINT	'Error while making entry of Job session details made into table DBA..whatIsRunning'
			PRINT	ERROR_MESSAGE();
		END CATCH

		IF (@p_ForceJobStop = 1)
		BEGIN
			BEGIN TRY
				PRINT	'Stopping the job '+@p_JobName;
				EXEC msdb..sp_stop_job @job_name = @p_JobName;
				SET @_mailSubject = 'Job '+QUOTENAME(@p_JobName)+' was stopped after found to be running for over '+CAST(@p_TimeLimit_Minutes AS VARCHAR(20))+' minutes.'
				SET @_mailBody = 'Job '+QUOTENAME(@p_JobName)+' was stopped after found to be running for over '+CAST(@p_TimeLimit_Minutes AS VARCHAR(20))+' minutes.' + '
		<p>
		Thanks & Regards,<br>
		SQL Server DBA Alert<br>
		<p>';

			END TRY
			BEGIN CATCH
				PRINT	'Some error occurred while stopping the job.';
				PRINT	ERROR_MESSAGE();
				SET @_mailSubject = 'Error while stopping Job '+QUOTENAME(@p_JobName)+' after '+CAST(@p_TimeLimit_Minutes AS VARCHAR(20))+' minutes';
				SET @_mailBody = 'Error while stopping Job <b>'+QUOTENAME(@p_JobName)+'</b> after <b>'+CAST(@p_TimeLimit_Minutes AS VARCHAR(20))+'</b> minutes' + '
		<p>	
		Thanks & Regards,<br>
		SQL Server DBA Alert<br>
		</p>';
			END CATCH
		END
		ELSE
		BEGIN			
			SET @_mailSubject = 'Job '+QUOTENAME(@p_JobName)+' has been running for over '+CAST(@p_TimeLimit_Minutes AS VARCHAR(20))+' minutes.'
			SET @_mailBody = 'Job '+QUOTENAME(@p_JobName)+' has been running for over '+CAST(@p_TimeLimit_Minutes AS VARCHAR(20))+' minutes.' + '
<br>Kindly notify appropriate users.

	<p>
	Thanks & Regards,<br>
	SQL Server DBA Alert<br>
	<p>';

			PRINT	'Job is found to be running. But not stopping the job. In order to stop the job, kindly use @p_ForceJobStop parameter.';
		END
	
		EXEC msdb.dbo.sp_send_dbmail  
			--@profile_name = @@SERVERNAME,  
			@body_format = 'HTML',
			--@recipients = 'ajay.dwivedi@contso.com',  
			@recipients = @p_recipients,
			@copy_recipients= @p_cc,
			@body = @_mailBody,  
			@subject = @_mailSubject ;
	
	END
	ELSE
		PRINT ' Either job is not running or it has not crossed threshold time of '+CAST(@p_TimeLimit_Minutes AS VARCHAR(20))+' minutes';
END -- Procedure

GO


