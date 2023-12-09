/*
1) Create stored procedure [usp_get_blocking_alert]
2) Setup Agent Job [(dba) Sdt-AlertBlocking]
*/

--USE <<Your-DBA-Database>>;
go

IF OBJECT_ID('dbo.usp_get_blocking_alert') IS NULL
	EXEC('CREATE PROCEDURE [dbo].[usp_get_blocking_alert] AS SELECT 1 AS [Dummy];')
GO

ALTER PROCEDURE [dbo].[usp_get_blocking_alert] 
		@recipients varchar(1000) = 'dba@company.com',
		@threshold_minutes int = 2,
		@delay_minutes int = 15,
		@verbose tinyint = 0,
		@alert_key varchar(100) = 'Alert-SdtBlocking',
		@job_name nvarchar(500) = '(dba) Alert-SdtBlocking',
		@is_test_alert bit = 1,
		@help BIT = 0
AS
BEGIN 
/*
	Version:		0.4
	Created By:		Ajay Kumar Dwivedi
	Purpose:		To have custom alerting system for Consistant Blocking
	Modifications:	2022-Mar-15 - Wrong blocking details in mail https://github.com/imajaydwivedi/SQLDBA-SSMS-Solution/issues/7
					2021-Dec-08 - Enhacement module to made it standard code, and implement Auto Clear

EXEC [dbo].[usp_get_blocking_alert] 
					@verbose = 2,
					@recipients = 'sqlagentservice@gmail.com',
					@threshold_minutes = 1,
					@delay_minutes = 2,
					@alert_key = 'Alert-SdtBlocking',
					@job_name = 'Alert-SdtBlocking',
					@is_test_alert = 0;
*/
	SET NOCOUNT ON;

	--	Global Variables
	IF @verbose > 0
		PRINT 'Inside usp_get_blocking_alert.'+char(10)+char(9)+'Declaring local variables..';
	DECLARE @_collection_time datetime;
	DECLARE @_latest_collection_time datetime;
	DECLARE @_second_latest_collection_time datetime;
	DECLARE @_mail_html  NVARCHAR(MAX) ;
	DECLARE @_subject VARCHAR(1000);
	DECLARE @_table_name VARCHAR(125);
	DECLARE @_column_list_4_table_header VARCHAR(MAX);
	DECLARE @_column_list_4_table_data VARCHAR(MAX);
	DECLARE @_css_style_green_background_header VARCHAR(MAX);
	DECLARE @_html_body VARCHAR(MAX);
	DECLARE @_sql_string VARCHAR(MAX);
	DECLARE @_data_4_table_data TABLE ( TableData VARCHAR(MAX) );
	DECLARE @_query_filter VARCHAR(2000);
	DECLARE @_send_mail bit = 0;
	DECLARE @_is_blocking_found bit = 0;
	DECLARE @_is_consistent_blocking_found bit = 0;
	DECLARE @_last_sent_blocking_active datetime;
	DECLARE @_last_sent_blocking_cleared datetime;
	DECLARE @_profile_name varchar(200);

	-- Store details in Variables 
	SET @_collection_time = GETDATE();

	IF OBJECT_ID('dbo.sdt_blocking_alert') IS NULL
		CREATE TABLE dbo.sdt_blocking_alert
		(
			[collection_time] datetime NULL,
			--[TimeInMinutes] bigint NULL,
			[dd hh:mm:ss.mss] varchar(2000),
			[blocking_tree] [nvarchar](max) NULL,
			[session_id] [smallint] NULL,
			[blocker_spid] [smallint] NULL,
			[blocked_counts] varchar(30) NULL,
			[status] varchar(30) NULL,
			--[sql_text] [xml] NULL,
			[host_name] varchar(128) NULL,
			[database_name] varchar(128) NULL,
			[login_name] varchar(128) NULL,
			[program_name] varchar(128) NULL,
			[wait_info] varchar(4000) NULL,
			--[blocked_session_count] varchar(30) NULL,
			--[locks] [xml] NULL,
			--[tran_start_time] smalldatetime NULL,
			[open_tran_count] smallint NULL,
			--[additional_info] [xml] NULL,
			[host_cpu_pcnt] tinyint,
			[cpu] [varchar](30) NULL,
			[tempdb_allocations] [varchar](30) NULL,
			[tempdb_current] [varchar](30) NULL,
			[reads] [varchar](30) NULL,
			[writes] [varchar](30) NULL
			--[physical_io] [varchar](30) NULL,
			--[physical_reads] [varchar](30) NULL			
		);
	ELSE
		TRUNCATE TABLE dbo.sdt_blocking_alert;
		--DROP TABLE dbo.sdt_blocking_alert;

	--	Get latest 2 collection_time
	IF(@verbose > 0)
		PRINT 'Get latest 2 collection_time';
	SELECT @_latest_collection_time = MAX(r.collection_time) FROM dbo.WhoIsActive as r WHERE r.collection_time <= @_collection_time;
	SELECT @_second_latest_collection_time = MAX(r.collection_time) FROM dbo.WhoIsActive as r 
		WHERE r.collection_time < @_latest_collection_time AND DATEDIFF(mi,r.collection_time,@_latest_collection_time) >= @threshold_minutes;
	
	IF(@verbose > 1)
	BEGIN
		PRINT CHAR(10)+'@_collection_time = '''+CONVERT(nvarchar(30),@_collection_time,121)+'''';
		PRINT '@_latest_collection_time = '''+CONVERT(nvarchar(30),@_latest_collection_time,121)+'''';
		PRINT '@_second_latest_collection_time = '''+CONVERT(nvarchar(30),@_second_latest_collection_time,121)+'''';
		PRINT '@threshold_minutes = ' + CONVERT(varchar,@threshold_minutes);
		PRINT '@delay_minutes = ' + CONVERT(varchar,@delay_minutes)+CHAR(10);
	END

	-- Get blocking details b/w latest 2 collection_time
	IF(@verbose > 0)
		PRINT 'Create table #WhoIsActive_Filtered'
	IF OBJECT_ID('tempdb..#WhoIsActive_Filtered') IS NOT NULL
		DROP TABLE #WhoIsActive_Filtered;
	SELECT	DENSE_RANK()OVER(ORDER BY collection_time ASC) AS CollectionBatch, *
	INTO	#WhoIsActive_Filtered
	FROM	dbo.WhoIsActive as r
	WHERE	r.collection_time IN (@_latest_collection_time, @_second_latest_collection_time )
		-- and line item is either victim, or blocker
		AND	(r.blocking_session_id IS NOT NULL OR r.session_id IN (SELECT h.blocking_session_id FROM dbo.WhoIsActive h WHERE h.collection_time = r.collection_time AND h.blocking_session_id IS NOT NULL));

	IF @verbose > 1
	BEGIN
		PRINT 'SELECT * FROM #WhoIsActive_Filtered;';
		SELECT [RunningQuery] = 'SELECT * FROM #WhoIsActive_Filtered',* FROM #WhoIsActive_Filtered;
	END

	-- Set blocking flag
	IF EXISTS ( SELECT * FROM #WhoIsActive_Filtered WHERE CollectionBatch = 2)
		SET @_is_blocking_found = 1;

	IF @_is_blocking_found = 1 /* If Blocking Found, Check for consistent blocking */
	BEGIN
		IF @verbose > 0
			PRINT 'Blocking found. Checking is its consistent..';

		-- Check is consistent blocking records are found by comparing both Batches
		IF(@verbose > 0)
			PRINT 'Creating table #WhoIsActive_Filtered_Blocking_SingleLine';
		IF OBJECT_ID('tempdb..#WhoIsActive_Filtered_Blocking_SingleLine') IS NOT NULL
			DROP TABLE #WhoIsActive_Filtered_Blocking_SingleLine;
		SELECT	c.CollectionBatch, c.collection_time, c.session_id, c.blocking_session_id, p.collection_time as previous_collection_time
		INTO	#WhoIsActive_Filtered_Blocking_SingleLine
		FROM #WhoIsActive_Filtered as c, #WhoIsActive_Filtered as p
		WHERE	c.CollectionBatch = 2 AND p.CollectionBatch = 1
			AND	c.session_id = p.session_id AND c.blocking_session_id = p.blocking_session_id
			AND	c.duration_minutes >= @threshold_minutes 
			AND c.login_name = p.login_name AND c.program_name = p.program_name AND c.database_name = p.database_name AND c.host_name = p.host_name

		IF @verbose > 1
		BEGIN
			PRINT 'SELECT * FROM #WhoIsActive_Filtered_Blocking_SingleLine'
			SELECT [RunningQuery] = 'SELECT * FROM #WhoIsActive_Filtered_Blocking_SingleLine', * FROM #WhoIsActive_Filtered_Blocking_SingleLine;
		END

		-- Delete Batches That are not valid for Consistent Blocking
		IF(@verbose > 0)
			PRINT 'Deleting non-consistant blocking records from #WhoIsActive_Filtered';
		DELETE r
		FROM #WhoIsActive_Filtered as r
		WHERE CollectionBatch = 1
			OR (CollectionBatch = 2 AND session_id NOT IN (SELECT b.session_id FROM #WhoIsActive_Filtered_Blocking_SingleLine as b) AND session_id NOT IN (SELECT b.blocking_session_id FROM #WhoIsActive_Filtered_Blocking_SingleLine as b));

		IF(@verbose > 1)
		BEGIN
			PRINT 'SELECT /* Consistent Blocking */ * FROM #WhoIsActive_Filtered';
			SELECT [RunningQuery] = 'SELECT /* Consistent Blocking */ * FROM #WhoIsActive_Filtered', * FROM #WhoIsActive_Filtered;
		END

		-- Create Blocking Tree
		IF(@verbose > 0)
			PRINT 'Populate table dbo.sdt_blocking_alert using CTE';
		;WITH T_JobCaptures AS
		(
			SELECT [dd hh:mm:ss.mss], [session_id], [sql_text], [login_name], [wait_info], [host_cpu_percent], [CPU], [tempdb_allocations], [tempdb_current], [blocking_session_id], [blocked_session_count], [status], [reads], [writes], [physical_reads], [used_memory], [open_tran_count], [percent_complete], [host_name], [database_name], [program_name], [start_time], [login_time], [request_id], [collection_time]
				,[sql_query] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(COALESCE([sql_text],null) AS VARCHAR(MAX)),char(13),''),CHAR(10),''),'<?query --',''),'--?>','')
				,[LEVEL] = CAST (REPLICATE ('0', 4-LEN (CAST (r.session_id AS VARCHAR))) + CAST (r.session_id AS VARCHAR) AS VARCHAR (1000))
			FROM #WhoIsActive_Filtered as r
			WHERE (ISNULL(r.blocking_session_id,0) = 0 OR ISNULL(r.blocking_session_id,0) = r.session_id)
			AND EXISTS (SELECT * FROM #WhoIsActive_Filtered AS R2 WHERE R2.collection_time = r.collection_time AND ISNULL(R2.blocking_session_id,0) = r.session_id AND ISNULL(R2.blocking_session_id,0) <> R2.session_id)
			--
			UNION ALL
			--
			SELECT r.[dd hh:mm:ss.mss], r.[session_id], r.[sql_text], r.[login_name], r.[wait_info], r.[host_cpu_percent], r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[blocking_session_id], r.[blocked_session_count], r.[status], r.[reads], r.[writes], r.[physical_reads], r.[used_memory], r.[open_tran_count], r.[percent_complete], r.[host_name], r.[database_name], r.[program_name], r.[start_time], r.[login_time], r.[request_id], r.[collection_time]
				,[sql_query] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(COALESCE(r.[sql_text],NULL) AS VARCHAR(MAX)),char(13),''),CHAR(10),''),'<?query --',''),'--?>','')
				,[LEVEL] = CAST (b.LEVEL + RIGHT (CAST ((1000 + r.session_id) AS VARCHAR (100)), 4) AS VARCHAR (1000))
			FROM T_JobCaptures AS b
			INNER JOIN #WhoIsActive_Filtered as r
				ON r.collection_time = b.collection_time
				AND	r.blocking_session_id = b.session_id
			WHERE	r.blocking_session_id <> r.session_id
		)
		INSERT dbo.sdt_blocking_alert
		SELECT	[collection_time], [dd hh:mm:ss.mss],
				[BLOCKING_TREE] = N'    ' + REPLICATE (N'|         ', LEN (LEVEL)/4 - 1) 
								+	CASE	WHEN (LEN(LEVEL)/4 - 1) = 0
											THEN 'HEAD -  '
											ELSE '|------  ' 
									END
								+	CAST (r.session_id AS NVARCHAR (10)) + N' ' + ISNULL((CASE WHEN LEFT(r.[sql_query],1) = '(' THEN SUBSTRING(r.[sql_query],CHARINDEX('exec',r.[sql_query]),LEN(r.[sql_query]))  ELSE r.[sql_query] END),''),
				[session_id], [blocking_session_id], [blocked_session_count], [status],
				--[sql_text], 
				[host_name], [database_name], [login_name], [program_name],	[wait_info],  
				--[locks], 
				[open_tran_count] --,additional_info
				,[host_cpu_percent], r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[reads], r.[writes]
		FROM	T_JobCaptures as r
		ORDER BY r.collection_time, LEVEL ASC;
							
		IF(@verbose > 1)
		BEGIN
			PRINT 'SELECT * FROM dbo.sdt_blocking_alert;';
			SELECT 'dbo.sdt_blocking_alert' AS RunningTable, * FROM dbo.sdt_blocking_alert;
		END
		
		IF EXISTS(SELECT * FROM dbo.sdt_blocking_alert)
		BEGIN
			SET @_is_consistent_blocking_found = 1;
			IF @verbose > 0
				PRINT 'Consistent blocking found.'
		END
	END

	/* 
	Check if Consistent Blocking, then based on Continous Threshold & Delay, send mail
	Check if No Error & No Consistent Blocking, then clear the Blocking alert if active
	*/
	
	IF @verbose > 0
		PRINT 'Get Last @_last_sent_blocking_active & @_last_sent_blocking_cleared..';
	SELECT @_last_sent_blocking_active = MAX(si.sent_date) FROM msdb..sysmail_sentitems si WHERE si.subject LIKE ('% - !['+@alert_key+'!] - ![ACTIVE!]') ESCAPE '!';
	SELECT @_last_sent_blocking_cleared = MAX(si.sent_date) FROM msdb..sysmail_sentitems si WHERE si.subject LIKE ('% - !['+@alert_key+'!] - ![CLEARED!]') ESCAPE '!';

	IF @verbose > 0
	BEGIN
		PRINT '@_last_sent_blocking_active => '+ISNULL(CONVERT(nvarchar(30),@_last_sent_blocking_active,121),'');
		PRINT '@_last_sent_blocking_cleared => '+ISNULL(CONVERT(nvarchar(30),@_last_sent_blocking_cleared,121),'');
		PRINT '@_is_blocking_found => '+CONVERT(varchar,@_is_blocking_found);
		PRINT '@_is_consistent_blocking_found => '+CONVERT(varchar,@_is_consistent_blocking_found);
	END

	SET @_css_style_green_background_header = N'
		<head><style>
		.GreenBackgroundHeader {
			font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
			border-collapse: collapse;
			width: 100%;
		}

		.GreenBackgroundHeader td, .GreenBackgroundHeader th {
			border: 1px solid #ddd;
			padding: 8px;
		}

		.GreenBackgroundHeader tr:nth-child(even){background-color: #f2f2f2;}

		.GreenBackgroundHeader tr:hover {background-color: #ddd;}

		.GreenBackgroundHeader th {
			padding-top: 12px;
			padding-bottom: 12px;
			text-align: left;
			background-color: #4CAF50;
			color: white;
		}
		</style><head>';

	IF @verbose > 0
		PRINT 'Check if Consistent Blocking and @delay_minutes is breached, then Set Mail Notification variables..'
	-- Check if Consistent Blocking, @delay_minutes is breached
	IF	@_is_consistent_blocking_found = 1
		AND (		(@_last_sent_blocking_active IS NULL) -- no alert active
				OR	(ISNULL(@_last_sent_blocking_cleared,@_last_sent_blocking_active) > @_last_sent_blocking_active) -- no alert active
				OR	(DATEDIFF(MINUTE,@_last_sent_blocking_active,GETDATE()) >= @delay_minutes) 
			)
	BEGIN
		-- Generate HTML table Headers/Rows
		IF(@verbose > 0)
			PRINT 'Inside Generate HTML table Headers/Rows';
		SET @_table_name = 'dbo.sdt_blocking_alert';

		-- Get table headers <th> data for Table <table>
		IF(@verbose > 0)
			PRINT 'Set value for @_column_list_4_table_header';
		SELECT	@_column_list_4_table_header = COALESCE(@_column_list_4_table_header ,'') + ('<th>'+COLUMN_NAME+'</th>'+CHAR(13)+CHAR(10))
		FROM	INFORMATION_SCHEMA.COLUMNS as c
		WHERE	TABLE_SCHEMA+'.'+c.TABLE_NAME = @_table_name
			AND	c.COLUMN_NAME NOT IN ('ID')
		ORDER BY COLUMN_NAME;

		IF(@verbose > 0)
			PRINT '@_column_list_4_table_header => ' + @_column_list_4_table_header;

		-- Get row (tr) data for Table <table>
		IF(@verbose > 0)
			PRINT 'Set Value for @_column_list_4_table_data';
		SELECT	@_column_list_4_table_data = COALESCE(@_column_list_4_table_data+', '''','+CHAR(13)+CHAR(10) ,'') + 
				('td = '+CASE WHEN COLUMN_NAME = 'BLOCKING_TREE' THEN 'LEFT(ISNULL('+COLUMN_NAME+','' ''),150)'
							WHEN COLUMN_NAME = 'dd hh:mm:ss.mss' THEN 'LEFT(LTRIM(RTRIM('+QUOTENAME(COLUMN_NAME)+')),18)'
							WHEN DATA_TYPE = 'xml' THEN 'ISNULL(LEFT(CAST('+COLUMN_NAME+' AS varchar(max)),150),'' '')'
							WHEN DATA_TYPE NOT LIKE '%char' AND IS_NULLABLE = 'YES' THEN 'ISNULL(CAST('+COLUMN_NAME+' AS varchar(125)),'' '')'
							WHEN DATA_TYPE NOT LIKE '%char' THEN 'CAST('+COLUMN_NAME+' AS VARCHAR(125))'
							WHEN IS_NULLABLE = 'YES' THEN 'ISNULL('+COLUMN_NAME+','' '')'
							ELSE COLUMN_NAME
							END)
		FROM	INFORMATION_SCHEMA.COLUMNS as c
		WHERE	TABLE_SCHEMA+'.'+c.TABLE_NAME = @_table_name
			AND	c.COLUMN_NAME NOT IN ('ID')
		ORDER BY COLUMN_NAME;

		IF(@verbose > 0)
			PRINT '@_column_list_4_table_data => ' + @_column_list_4_table_data;

		IF(@verbose > 0)
			PRINT 'Populating table @_data_4_table_data';
		SET @_sql_string = N'
			SELECT CAST ( ( SELECT '+@_column_list_4_table_data+'
							FROM '+@_table_name+'
							WHERE 1 = 1 '+ISNULL(@_query_filter,'')+'
							FOR XML PATH(''tr''), TYPE   
				) AS NVARCHAR(MAX) )';

		INSERT @_data_4_table_data
		EXEC (@_sql_string);

		IF(@verbose > 0)
		BEGIN
			PRINT 'SELECT * FROM @_data_4_table_data;'
			SELECT '@_data_4_table_data' as RunningTable, * FROM @_data_4_table_data;
		END

		IF(@verbose > 0)
			PRINT 'SELECT @_column_list_4_table_data = TableData FROM @_data_4_table_data;'
		SELECT @_column_list_4_table_data = TableData FROM @_data_4_table_data;
		IF(@verbose > 0)
			PRINT '@_column_list_4_table_data => '+@_column_list_4_table_data;

		IF @verbose > 0
			PRINT 'Setting Mail variable values for Blocking ACTIVE notification..'
		SET @_subject = QUOTENAME(@@SERVERNAME)+' - ['+@alert_key+'] - [ACTIVE]';
		--DECLARE @_default_html_style VARCHAR(100) = 'GreenBackgroundHeader';

		SET @_html_body = N'<H1>'+@_subject+'</H1>' +  
				N'<table border="1" class="GreenBackgroundHeader">' +  
				N'<tr>'+@_column_list_4_table_header+'</tr>' +  
				+@_column_list_4_table_data+
				N'</table>' ;  

		SET @_html_body = @_html_body + '
		<br><br>
		<p>To get more details, Kindly execute below query on ['+DB_NAME()+'] database-<br><br><code>
		select * from ['+DB_NAME()+'].dbo.WhoIsActive where collection_time = '''+convert(varchar,@_latest_collection_time,121)+''' and (blocking_session_id is not null or blocked_session_count > 0);</code>
		</p><br><br>
		Thanks & Regards,<br>
		Job ['+@job_name+']<br>
		Alert Generated @ '+CONVERT(varchar(30),@_collection_time,121)+'<br></p>'+
		N'<br><br>// Blocking Threshold (Minutes) -> ' + CONVERT(varchar,@threshold_minutes) +
		N'<br>// Notification Delay (Minutes) -> ' + CONVERT(varchar,@delay_minutes)

		SET @_mail_html =  @_css_style_green_background_header + @_html_body;
		SET @_send_mail = 1;
	END
	ELSE
		PRINT 'IMPORTANT => Blocking "Active" mail notification checks not satisfied. '+char(10)+char(9)+'@_is_consistent_blocking_found = 1 AND ( (@_last_sent_blocking_active IS NULL) OR	(ISNULL(@_last_sent_blocking_cleared,@_last_sent_blocking_active) > @_last_sent_blocking_active) OR (DATEDIFF(MINUTE,@_last_sent_blocking_active,GETDATE()) >= @delay_minutes) )';

	-- If no consistent blocking found, then clear the active alert
	IF (@_is_consistent_blocking_found = 0) AND (@_last_sent_blocking_active >= ISNULL(@_last_sent_blocking_cleared,@_last_sent_blocking_active))
	BEGIN
		IF @verbose > 0
			PRINT 'Setting Mail variable values for Blocking CLEARED notification..'
		SET @_subject = QUOTENAME(@@SERVERNAME)+' - ['+@alert_key+'] - [CLEARED]';

		SET @_html_body = N'<H1>'+@_subject+'</H1>'

		SET @_html_body = @_html_body + '
		<p>
		<br><br>
		Thanks & Regards,<br>
		Job ['+@job_name+']<br>
		Alert Generated @ '+CONVERT(varchar(30),@_collection_time,121)+'<br></p>'+
		N'<br>// Blocking Threshold (Minutes) -> ' + CONVERT(varchar,@threshold_minutes) +
		N'<br>// Notification Delay (Minutes) -> ' + CONVERT(varchar,@delay_minutes)

		SET @_mail_html =  @_css_style_green_background_header + @_html_body;
		SET @_send_mail = 1;
	END
	ELSE
		PRINT 'IMPORTANT => Blocking "CLEARED" mail notification checks not satisfied. '+char(10)+char(9)+'(@_is_consistent_blocking_found = 0) AND (@_last_sent_blocking_active >= ISNULL(@_last_sent_blocking_cleared,@_last_sent_blocking_active))';
		
	IF @is_test_alert = 1
		SET @_subject = 'TestAlert - '+@_subject;

	IF @_send_mail = 1
	BEGIN
		SELECT @_profile_name = p.name
		FROM msdb.dbo.sysmail_profile p 
		JOIN msdb.dbo.sysmail_principalprofile pp ON pp.profile_id = p.profile_id AND pp.is_default = 1
		JOIN msdb.dbo.sysmail_profileaccount pa ON p.profile_id = pa.profile_id 
		JOIN msdb.dbo.sysmail_account a ON pa.account_id = a.account_id 
		JOIN msdb.dbo.sysmail_server s ON a.account_id = s.account_id;

		EXEC msdb.dbo.sp_send_dbmail
				@recipients = @recipients,
				@profile_name = @_profile_name,
				@subject = @_subject,
				@body = @_mail_html,
				@body_format = 'HTML';
	END
END
GO


USE [msdb]
GO

/****** Object:  Job [(dba) Alert-SdtBlocking]    Script Date: 12/8/2021 8:52:01 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 12/8/2021 8:52:01 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'(dba) Alert-SdtBlocking', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Blocking Alert using [dbo].[usp_get_blocking_alert]', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [usp_get_blocking_alert]    Script Date: 12/8/2021 8:52:02 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'usp_get_blocking_alert', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_WARNINGS ON;

-- Parameters
DECLARE @send_error_mail bit = 1;
DECLARE @blocking_threshold_minutes tinyint = 2;
DECLARE @threshold_continous_failure tinyint = 3;
DECLARE @notification_delay_minutes tinyint = 10;
DECLARE @is_test_alert bit = 0;
DECLARE @verbose tinyint = 0; /* 0 - no messages, 1 - debug messages, 2 = debug messages + table results */
DECLARE @recipients varchar(500) = ''sqlagentservice@gmail.com'';
DECLARE @alert_key varchar(100) = ''Alert-SdtBlocking'';

/* Additional Requirements
1) Default Global Mail Profile
	-> SqlInstance -> Management -> Right click "Database Mail" -> Configure Database Mail -> Select option "Manage profile security" -> Check Public checkbox, and Select "Yes" for Default for profile that should be set a global default
2) Make sure context database is set to correct dba database
*/

--DECLARE @_output VARCHAR(8000);
--SET @_output = ''Declare local variables''+CHAR(10);
-- Local Variables
--DECLARE @_rows_affected int = 0;
DECLARE @_s NVARCHAR(MAX);
DECLARE @_collection_time datetime = GETDATE();
--DECLARE @_columns VARCHAR(8000);
--DECLARE @_cpu_system int;
--DECLARE @_cpu_sql int;
DECLARE @_last_sent_failed_active datetime;
DECLARE @_last_sent_failed_cleared datetime;
DECLARE @_mail_body_html NVARCHAR(MAX);  
DECLARE @_subject nvarchar(1000);
DECLARE @_job_name nvarchar(500);
DECLARE @_continous_failures tinyint = 0;
DECLARE @_send_mail bit = 0;

IF @verbose > 0
	PRINT ''Dynamically fetch @_job_name ..''
SET @_job_name = ''(dba) ''+@alert_key;
IF program_name() LIKE ''SQLAgent - TSQL JobStep (Job %''
	EXEC sp_executesql	@stmt = N''SELECT @_job_name_OUTPUT = name FROM msdb.dbo.sysjobs WHERE job_id = CONVERT(uniqueidentifier, $(ESCAPE_NONE(JOBID)))'',
						@params = N''@_job_name_OUTPUT nvarchar(500) OUTPUT'',
						@_job_name_OUTPUT = @_job_name OUTPUT;
--PRINT ''"''+@_job_name+''"'';

-- Variables for Try/Catch Block
DECLARE @_profile_name varchar(200);
DECLARE	@_errorNumber int,
		@_errorSeverity int,
		@_errorState int,
		@_errorLine int,
		@_errorMessage nvarchar(4000);

BEGIN TRY
	IF @verbose > 0
		PRINT ''Start Try Block..'';	
	EXEC [dbo].[usp_get_blocking_alert] 
					@verbose = @verbose,
					@recipients = @recipients,
					@threshold_minutes = @blocking_threshold_minutes,
					@delay_minutes = @notification_delay_minutes,
					@alert_key = @alert_key,
					@job_name = @_job_name,
					@is_test_alert = @is_test_alert;
END TRY  -- Perform main logic inside Try/Catch
BEGIN CATCH
	IF @verbose > 0
		PRINT ''Start Catch Block.''

	SELECT @_errorNumber	 = Error_Number()
			,@_errorSeverity = Error_Severity()
			,@_errorState	 = Error_State()
			,@_errorLine	 = Error_Line()
			,@_errorMessage	 = Error_Message();

	IF OBJECT_ID(''tempdb..#CommandLog'') IS NOT NULL
		TRUNCATE TABLE #CommandLog;
	ELSE
		CREATE TABLE #CommandLog(collection_time datetime2 not null, status varchar(30) not null);

	IF @verbose > 0
		PRINT CHAR(9)+''Inside Catch Block. Get recent ''+cast(@threshold_continous_failure as varchar)+'' execution entries from logs..''
	SET @_s = N''
	DECLARE @threshold_continous_failure tinyint = @_threshold_continous_failure;
	SET @threshold_continous_failure -= 1;
	SELECT	[run_date_time] = msdb.dbo.agent_datetime(run_date, run_time),
			[status] = case when run_status = 1 then ''''Success'''' else ''''Failure'''' end
	FROM msdb.dbo.sysjobs jobs
	INNER JOIN msdb.dbo.sysjobhistory history ON jobs.job_id = history.job_id
	WHERE jobs.enabled = 1 AND jobs.name = @_job_name AND step_id = 0 AND run_status NOT IN (2,4) -- not retry/inprogress
	ORDER BY run_date_time DESC OFFSET 0 ROWS FETCH FIRST @threshold_continous_failure ROWS ONLY;'' + char(10);
	IF @verbose > 1
		PRINT CHAR(9)+@_s;
	INSERT #CommandLog
	EXEC sp_executesql @_s, N''@_job_name varchar(500), @_threshold_continous_failure tinyint'', @_job_name = @_job_name, @_threshold_continous_failure = @threshold_continous_failure;

	SELECT @_continous_failures = COUNT(*)+1 FROM #CommandLog WHERE [status] = ''Failure'';

	IF @verbose > 0
		PRINT CHAR(9)+''@_continous_failures => ''+cast(@_continous_failures as varchar);
	IF @verbose > 1
	BEGIN
		PRINT CHAR(9)+''SELECT [RunningQuery] = ''''Previous Run Status from #CommandLog'''', * FROM #CommandLog;''
		SELECT [RunningQuery], cl.* 
		FROM #CommandLog cl
		FULL OUTER JOIN (VALUES (''Previous Run Status from #CommandLog'')) rq (RunningQuery)
		ON 1 = 1;
	END

	IF @verbose > 0
		PRINT ''End Catch Block.''
END CATCH	

/* 
Check if Any Error, then based on Continous Threshold & Delay, send mail
Check if No Error, then clear the alert if active,
*/

IF @verbose > 0
	PRINT ''Get Last @last_sent_failed &  @last_sent_cleared..'';
SELECT @_last_sent_failed_active = MAX(si.sent_date) FROM msdb..sysmail_sentitems si WHERE si.subject LIKE (''% - Job ![''+@_job_name+''!] - ![FAILED!] - ![ACTIVE!]'') ESCAPE ''!'';
SELECT @_last_sent_failed_cleared = MAX(si.sent_date) FROM msdb..sysmail_sentitems si WHERE si.subject LIKE (''% - Job ![''+@_job_name+''!] - ![FAILED!] - ![CLEARED!]'') ESCAPE ''!'';

IF @verbose > 0
BEGIN
	PRINT ''@_last_sent_failed_active => ''+CONVERT(nvarchar(30),@_last_sent_failed_active,121);
	PRINT ''@_last_sent_failed_cleared => ''+ISNULL(CONVERT(nvarchar(30),@_last_sent_failed_cleared,121),'''');
END

-- Check if Failed, @threshold_continous_failure is breached, and crossed @notification_delay_minutes
IF		(@send_error_mail = 1) 
	AND (@_continous_failures >= @threshold_continous_failure) 
	AND ( (@_last_sent_failed_active IS NULL) OR (DATEDIFF(MINUTE,@_last_sent_failed_active,GETDATE()) >= @notification_delay_minutes) )
BEGIN
	IF @verbose > 0
		PRINT ''Setting Mail variable values for Job FAILED ACTIVE notification..''
	SET @_subject = QUOTENAME(@@SERVERNAME)+'' - Job [''+@_job_name+''] - [FAILED] - [ACTIVE]'';
	SET @_mail_body_html =
			N''Sql Agent job ''''''+@_job_name+'''''' has failed @''+ CONVERT(nvarchar(30),getdate(),121) +''.''+
			N''<br><br>Error Number: '' + convert(varchar, @_errorNumber) + 
			N''<br>Line Number: '' + convert(varchar, @_errorLine) +
			N''<br>Error Message: <br>"'' + @_errorMessage +
			N''<br><br>Kindly resolve the job failure based on above error message.''+
			N''<br><br>Regards,''+
			N''<br>Job [''+@_job_name+'']'' +
			N''<br><br>--> Continous Failure Threshold -> '' + CONVERT(varchar,@threshold_continous_failure) +
			N''<br>--> Notification Delay (Minutes) -> '' + CONVERT(varchar,@notification_delay_minutes)
	SET @_send_mail = 1;
END
ELSE
	PRINT ''IMPORTANT => Failure "Active" mail notification checks not satisfied. ''+char(10)+char(9)+''((@send_error_mail = 1) AND (@_continous_failures >= @threshold_continous_failure) AND ( (@last_sent_failed IS NULL) OR (DATEDIFF(MINUTE,@last_sent_failed,GETDATE()) >= @notification_delay_minutes) ))'';

-- Check if No error, then clear active alert if any.
IF (@send_error_mail = 1) AND (@_errorMessage IS NULL) AND (@_last_sent_failed_active >= ISNULL(@_last_sent_failed_cleared,@_last_sent_failed_active))
BEGIN
	IF @verbose > 0
		PRINT ''Setting Mail variable values for Job FAILED CLEARED notification..''
	SET @_subject = QUOTENAME(@@SERVERNAME)+'' - Job [''+@_job_name+''] - [FAILED] - [CLEARED]'';
	SET @_mail_body_html=
			N''Sql Agent job ''''''+@_job_name+'''''' has completed successfully. So clearing alert @''+ CONVERT(nvarchar(30),getdate(),121) +''.''+
			N''<br><br>Regards,''+
			N''<br>Job [''+@_job_name+'']'' +
			N''<br><br>--> Continous Failure Threshold -> '' + CONVERT(varchar,@threshold_continous_failure) +
			N''<br>--> Notification Delay (Minutes) -> '' + CONVERT(varchar,@notification_delay_minutes)
	SET @_send_mail = 1;
END
ELSE
	PRINT ''IMPORTANT => Failure "Clearing" mail notification checks not satisfied. ''+char(10)+char(9)+''(@send_error_mail = 1) AND (@_errorMessage IS NULL) AND (@_last_sent_failed_active > @_last_sent_failed_cleared)'';

IF @is_test_alert = 1
	SET @_subject = ''TestAlert - ''+@_subject;

IF @_send_mail = 1
BEGIN
	SELECT @_profile_name = p.name
	FROM msdb.dbo.sysmail_profile p 
	JOIN msdb.dbo.sysmail_principalprofile pp ON pp.profile_id = p.profile_id AND pp.is_default = 1
	JOIN msdb.dbo.sysmail_profileaccount pa ON p.profile_id = pa.profile_id 
	JOIN msdb.dbo.sysmail_account a ON pa.account_id = a.account_id 
	JOIN msdb.dbo.sysmail_server s ON a.account_id = s.account_id;

	EXEC msdb.dbo.sp_send_dbmail
			@recipients = @recipients,
			@profile_name = @_profile_name,
			@subject = @_subject,
			@body = @_mail_body_html,
			@body_format = ''HTML'';
END

IF @_errorMessage IS NOT NULL --AND @send_error_mail = 0
	THROW 50000, @_errorMessage, 1;', 
		@database_name=N'DBA', 
		@flags=12
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'(dba) Sdt-AlertBlocking', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=2, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20211208, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'5aa86605-c03c-441c-b4b4-8a652a247719'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


