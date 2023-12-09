SET NOCOUNT ON; 
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET QUOTED_IDENTIFIER OFF;
SET ANSI_WARNINGS OFF;

use DBA;

-- Parameters
declare @consistent_blocking_threshold_minutes int = 1;

-- Local Variables
declare @current_time_utc datetime;
declare @current_time datetime;
declare @has_consistent_blocking bit = 0;
declare @database_name sysname;
declare @sql_n NVARCHAR(MAX);

-- Drop temp tables
IF OBJECT_ID('tempdb..#Blockings') IS NOT NULL
	DROP TABLE #Blockings;
IF OBJECT_ID('tempdb..#SysProcesses') IS NOT NULL
	DROP TABLE #SysProcesses;
if OBJECT_ID('tempdb..#snapshot_current') is not null
	drop table #snapshot_current;
if OBJECT_ID('tempdb..#snapshot_previous') is not null
	drop table #snapshot_previous;
if object_id('tempdb..#locks') is not null
	drop table #locks;

-- Initialize local variables
SELECT @current_time_utc = GETUTCDATE(), @current_time = GETDATE();

-- Identify the Lead Blocker (RealTime)
select  Concat
        (
            RIGHT('00'+CAST(ISNULL((datediff(second,er.start_time,@current_time) / 3600 / 24), 0) AS VARCHAR(2)),2)
            ,' '
            ,RIGHT('00'+CAST(ISNULL(datediff(second,er.start_time,@current_time) / 3600  % 24, 0) AS VARCHAR(2)),2)
            ,':'
            ,RIGHT('00'+CAST(ISNULL(datediff(second,er.start_time,@current_time) / 60 % 60, 0) AS VARCHAR(2)),2)
            ,':'
            ,RIGHT('00'+CAST(ISNULL(datediff(second,er.start_time,@current_time) % 60, 0) AS VARCHAR(2)),2)
        ) as [dd hh:mm:ss]
		,r.spid as session_id
		,t.text as sql_command
		,SUBSTRING(t.text, (r.stmt_start/2)+1,   
        ((CASE r.stmt_end WHEN -1 THEN DATALENGTH(t.text)  
				ELSE r.stmt_end END - r.stmt_start)/2) + 1) AS sql_text
		,r.cmd as command
		,r.loginame as login_name
		,db_name(r.dbid) as database_name
		,[program_name] = CASE	WHEN	r.program_name like 'SQLAgent - TSQL JobStep %'
				THEN	(	select	top 1 'SQL Job = '+j.name 
							from msdb.dbo.sysjobs (nolock) as j
							inner join msdb.dbo.sysjobsteps (nolock) AS js on j.job_id=js.job_id
							where right(cast(js.job_id as nvarchar(50)),10) = RIGHT(substring(r.program_name,30,34),10) 
						) + ' ( '+SUBSTRING(LTRIM(RTRIM(r.program_name)), CHARINDEX(': Step ',LTRIM(RTRIM(r.program_name)))+2,LEN(LTRIM(RTRIM(r.program_name)))-CHARINDEX(': Step ',LTRIM(RTRIM(r.program_name)))-2)+' )'
				ELSE	r.program_name
				END
		,(case when r.waittime = 0 then null else r.lastwaittype end) as wait_type
		,r.waittime as wait_time
		,(SELECT CASE
				WHEN pageid = 1 OR pageid % 8088 = 0 THEN 'PFS'
				WHEN pageid = 2 OR pageid % 511232 = 0 THEN 'GAM'
				WHEN pageid = 3 OR (pageid - 1) % 511232 = 0 THEN 'SGAM'
				WHEN pageid IS NULL THEN NULL
				ELSE 'Not PFS/GAM/SGAM' END
				FROM (SELECT CASE WHEN er.[wait_type] LIKE 'PAGE%LATCH%' AND er.[wait_resource] LIKE '%:%'
				THEN CAST(RIGHT(er.[wait_resource], LEN(er.[wait_resource]) - CHARINDEX(':', er.[wait_resource], LEN(er.[wait_resource])-CHARINDEX(':', REVERSE(er.[wait_resource])))) AS INT)
				ELSE NULL END AS pageid) AS latch_pageid
		) AS wait_resource_type
		,null as tempdb_allocations
		,null as tempdb_current
		,r.blocked as blocking_session_id
		,er.logical_reads as reads
		,er.writes as writes
		,r.physical_io
		,r.cpu
		,r.memusage
		,r.status
		,r.open_tran
		,r.hostname as host_name
		,er.start_time as start_time
		,r.login_time as login_time
		--,sql_plan = CAST(sqp.query_plan AS xml)
		,er.plan_handle,er.statement_start_offset, er.statement_end_offset
		,@current_time_utc as collection_time_utc
		,er.request_id ,hostprocess ,last_batch ,r.dbid ,des.last_request_start_time
		,cast(null as xml) as locks
INTO #SysProcesses
from sys.sysprocesses as r left join sys.dm_exec_requests as er	on er.session_id = r.spid
left join sys.dm_exec_sessions as des on des.session_id = r.spid
CROSS APPLY sys.dm_exec_sql_text(r.SQL_HANDLE) as t
--OUTER APPLY sys.dm_exec_text_query_plan(er.plan_handle,er.statement_start_offset, er.statement_end_offset) as sqp
where r.blocked <> 0 and r.spid in (select p.blocked from sys.sysprocesses p where p.blocked <> 0)

if exists (select * from #SysProcesses)
begin
	delete from #SysProcesses 
	where session_id not in (
						-- session part of blocking
						select r.session_id from #SysProcesses AS r 
						where r.blocking_session_id <> 0 -- blocked
						or r.session_id in (select l.blocking_session_id from #SysProcesses AS l where l.blocking_session_id <> 0) -- blocker
					);

	create clustered index [ci_#SysProcesses] on #SysProcesses (session_id, blocking_session_id, collection_time_utc);

	-- Generate [locks] xml data
	if exists(select * from #SysProcesses AS r where blocking_session_id <> 0 and blocking_session_id <> session_id)
	BEGIN
		-- Collect locks metadata from sys.dm_tran_locks
		SELECT
			y.resource_type,
			y.database_name,
			y.object_id,
			y.file_id,
			y.page_type,
			y.hobt_id,
			y.allocation_unit_id,
			y.index_id,
			y.schema_id,
			y.principal_id,
			y.request_mode,
			y.request_status,
			y.session_id,
			y.resource_description,
			y.request_count,
			s.request_id,
			s.start_time,
			CONVERT(sysname, NULL) AS object_name,
			CONVERT(sysname, NULL) AS index_name,
			CONVERT(sysname, NULL) AS schema_name,
			CONVERT(sysname, NULL) AS principal_name,
			CONVERT(NVARCHAR(2048), NULL) AS query_error
		INTO #locks
		FROM
		(
			SELECT
				session_id,
				CASE sp.status
					WHEN 'sleeping' THEN CONVERT(INT, 0)
					ELSE sp.request_id
				END AS request_id,
				CASE sp.status
					WHEN 'sleeping' THEN sp.last_batch
					ELSE COALESCE(req.start_time, sp.last_batch)
				END AS start_time,
				sp.dbid
			FROM #SysProcesses AS sp
			OUTER APPLY
			(
				SELECT TOP(1)
					CASE
						WHEN 
						(
							sp.hostprocess > ''
							OR r.total_elapsed_time < 0
						) THEN
							r.start_time
						ELSE
							DATEADD
							(
								ms, 
								1000 * (DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), @current_time)) / 500) - DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), @current_time)), 
								DATEADD(second, -(r.total_elapsed_time / 1000), @current_time)
							)
					END AS start_time
				FROM sys.dm_exec_requests AS r
				WHERE
					r.session_id = sp.session_id
					AND r.request_id = sp.request_id
			) AS req
			WHERE
				--Process inclusive filter
				1 = 1 -- session filter here
				--Process exclusive filter
		) AS s
		INNER HASH JOIN
		(
			SELECT
				x.resource_type,
				x.database_name,
				x.object_id,
				x.file_id,
				CASE
					WHEN x.page_no = 1 OR x.page_no % 8088 = 0 THEN 'PFS'
					WHEN x.page_no = 2 OR x.page_no % 511232 = 0 THEN 'GAM'
					WHEN x.page_no = 3 OR (x.page_no - 1) % 511232 = 0 THEN 'SGAM'
					WHEN x.page_no = 6 OR (x.page_no - 6) % 511232 = 0 THEN 'DCM'
					WHEN x.page_no = 7 OR (x.page_no - 7) % 511232 = 0 THEN 'BCM'
					WHEN x.page_no IS NOT NULL THEN '*'
					ELSE NULL
				END AS page_type,
				x.hobt_id,
				x.allocation_unit_id,
				x.index_id,
				x.schema_id,
				x.principal_id,
				x.request_mode,
				x.request_status,
				x.session_id,
				x.request_id,
				CASE
					WHEN COALESCE(x.object_id, x.file_id, x.hobt_id, x.allocation_unit_id, x.index_id, x.schema_id, x.principal_id) IS NULL THEN NULLIF(resource_description, '')
					ELSE NULL
				END AS resource_description,
				COUNT(*) AS request_count
			FROM
			(
				SELECT
					tl.resource_type +
						CASE
							WHEN tl.resource_subtype = '' THEN ''
							ELSE '.' + tl.resource_subtype
						END AS resource_type,
					COALESCE(DB_NAME(tl.resource_database_id), N'(null)') AS database_name,
					CONVERT
					(
						INT,
						CASE
							WHEN tl.resource_type = 'OBJECT' THEN tl.resource_associated_entity_id
							WHEN tl.resource_description LIKE '%object_id = %' THEN
								(
									SUBSTRING
									(
										tl.resource_description, 
										(CHARINDEX('object_id = ', tl.resource_description) + 12), 
										COALESCE
										(
											NULLIF
											(
												CHARINDEX(',', tl.resource_description, CHARINDEX('object_id = ', tl.resource_description) + 12),
												0
											), 
											DATALENGTH(tl.resource_description)+1
										) - (CHARINDEX('object_id = ', tl.resource_description) + 12)
									)
								)
							ELSE NULL
						END
					) AS object_id,
					CONVERT
					(
						INT,
						CASE 
							WHEN tl.resource_type = 'FILE' THEN CONVERT(INT, tl.resource_description)
							WHEN tl.resource_type IN ('PAGE', 'EXTENT', 'RID') THEN LEFT(tl.resource_description, CHARINDEX(':', tl.resource_description)-1)
							ELSE NULL
						END
					) AS file_id,
					CONVERT
					(
						INT,
						CASE
							WHEN tl.resource_type IN ('PAGE', 'EXTENT', 'RID') THEN 
								SUBSTRING
								(
									tl.resource_description, 
									CHARINDEX(':', tl.resource_description) + 1, 
									COALESCE
									(
										NULLIF
										(
											CHARINDEX(':', tl.resource_description, CHARINDEX(':', tl.resource_description) + 1), 
											0
										), 
										DATALENGTH(tl.resource_description)+1
									) - (CHARINDEX(':', tl.resource_description) + 1)
								)
							ELSE NULL
						END
					) AS page_no,
					CASE
						WHEN tl.resource_type IN ('PAGE', 'KEY', 'RID', 'HOBT') THEN tl.resource_associated_entity_id
						ELSE NULL
					END AS hobt_id,
					CASE
						WHEN tl.resource_type = 'ALLOCATION_UNIT' THEN tl.resource_associated_entity_id
						ELSE NULL
					END AS allocation_unit_id,
					CONVERT
					(
						INT,
						CASE
							WHEN
								/*TODO: Deal with server principals*/ 
								tl.resource_subtype <> 'SERVER_PRINCIPAL' 
								AND tl.resource_description LIKE '%index_id or stats_id = %' THEN
								(
									SUBSTRING
									(
										tl.resource_description, 
										(CHARINDEX('index_id or stats_id = ', tl.resource_description) + 23), 
										COALESCE
										(
											NULLIF
											(
												CHARINDEX(',', tl.resource_description, CHARINDEX('index_id or stats_id = ', tl.resource_description) + 23), 
												0
											), 
											DATALENGTH(tl.resource_description)+1
										) - (CHARINDEX('index_id or stats_id = ', tl.resource_description) + 23)
									)
								)
							ELSE NULL
						END 
					) AS index_id,
					CONVERT
					(
						INT,
						CASE
							WHEN tl.resource_description LIKE '%schema_id = %' THEN
								(
									SUBSTRING
									(
										tl.resource_description, 
										(CHARINDEX('schema_id = ', tl.resource_description) + 12), 
										COALESCE
										(
											NULLIF
											(
												CHARINDEX(',', tl.resource_description, CHARINDEX('schema_id = ', tl.resource_description) + 12), 
												0
											), 
											DATALENGTH(tl.resource_description)+1
										) - (CHARINDEX('schema_id = ', tl.resource_description) + 12)
									)
								)
							ELSE NULL
						END 
					) AS schema_id,
					CONVERT
					(
						INT,
						CASE
							WHEN tl.resource_description LIKE '%principal_id = %' THEN
								(
									SUBSTRING
									(
										tl.resource_description, 
										(CHARINDEX('principal_id = ', tl.resource_description) + 15), 
										COALESCE
										(
											NULLIF
											(
												CHARINDEX(',', tl.resource_description, CHARINDEX('principal_id = ', tl.resource_description) + 15), 
												0
											), 
											DATALENGTH(tl.resource_description)+1
										) - (CHARINDEX('principal_id = ', tl.resource_description) + 15)
									)
								)
							ELSE NULL
						END
					) AS principal_id,
					tl.request_mode,
					tl.request_status,
					tl.request_session_id AS session_id,
					tl.request_request_id AS request_id,

					/*TODO: Applocks, other resource_descriptions*/
					RTRIM(tl.resource_description) AS resource_description,
					tl.resource_associated_entity_id
					/*********************************************/
				FROM 
				(
					SELECT 
						request_session_id,
						CONVERT(VARCHAR(120), resource_type) COLLATE Latin1_General_Bin2 AS resource_type,
						CONVERT(VARCHAR(120), resource_subtype) COLLATE Latin1_General_Bin2 AS resource_subtype,
						resource_database_id,
						CONVERT(VARCHAR(512), resource_description) COLLATE Latin1_General_Bin2 AS resource_description,
						resource_associated_entity_id,
						CONVERT(VARCHAR(120), request_mode) COLLATE Latin1_General_Bin2 AS request_mode,
						CONVERT(VARCHAR(120), request_status) COLLATE Latin1_General_Bin2 AS request_status,
						request_request_id
					FROM sys.dm_tran_locks
				) AS tl
			) AS x
			GROUP BY
				x.resource_type,
				x.database_name,
				x.object_id,
				x.file_id,
				CASE
					WHEN x.page_no = 1 OR x.page_no % 8088 = 0 THEN 'PFS'
					WHEN x.page_no = 2 OR x.page_no % 511232 = 0 THEN 'GAM'
					WHEN x.page_no = 3 OR (x.page_no - 1) % 511232 = 0 THEN 'SGAM'
					WHEN x.page_no = 6 OR (x.page_no - 6) % 511232 = 0 THEN 'DCM'
					WHEN x.page_no = 7 OR (x.page_no - 7) % 511232 = 0 THEN 'BCM'
					WHEN x.page_no IS NOT NULL THEN '*'
					ELSE NULL
				END,
				x.hobt_id,
				x.allocation_unit_id,
				x.index_id,
				x.schema_id,
				x.principal_id,
				x.request_mode,
				x.request_status,
				x.session_id,
				x.request_id,
				CASE
					WHEN COALESCE(x.object_id, x.file_id, x.hobt_id, x.allocation_unit_id, x.index_id, x.schema_id, x.principal_id) IS NULL THEN NULLIF(resource_description, '')
					ELSE NULL
				END
		) AS y ON
			y.session_id = s.session_id
			AND y.request_id = s.request_id
		OPTION (HASH GROUP);

		--Disable unnecessary autostats on the table
		CREATE STATISTICS s_database_name ON #locks (database_name)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_object_id ON #locks (object_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_hobt_id ON #locks (hobt_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_allocation_unit_id ON #locks (allocation_unit_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_index_id ON #locks (index_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_schema_id ON #locks (schema_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_principal_id ON #locks (principal_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_request_id ON #locks (request_id)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_start_time ON #locks (start_time)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_resource_type ON #locks (resource_type)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_object_name ON #locks (object_name)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_schema_name ON #locks (schema_name)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_page_type ON #locks (page_type)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_request_mode ON #locks (request_mode)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_request_status ON #locks (request_status)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_resource_description ON #locks (resource_description)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_index_name ON #locks (index_name)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;
		CREATE STATISTICS s_principal_name ON #locks (principal_name)
		WITH SAMPLE 0 ROWS, NORECOMPUTE;


		-- Convert lock data into XML
		DECLARE locks_cursor
		CURSOR LOCAL FAST_FORWARD
		FOR 
			SELECT DISTINCT
				database_name
			FROM #locks
			WHERE
				EXISTS
				(
					SELECT *
					FROM #SysProcesses AS s
					WHERE
						s.session_id = #locks.session_id
				)
				AND database_name <> '(null)'
			OPTION (KEEPFIXED PLAN);

		OPEN locks_cursor;

		FETCH NEXT FROM locks_cursor
		INTO 
			@database_name;

		WHILE @@FETCH_STATUS = 0
		BEGIN;
			BEGIN TRY;
				SET @sql_n = CONVERT(NVARCHAR(MAX), '') +
					'UPDATE l ' +
					'SET ' +
						'object_name = ' +
							'REPLACE ' +
							'( ' +
								'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
								'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
								'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'o.name COLLATE Latin1_General_Bin2, ' +
									'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
									'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
									'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
								'NCHAR(0), ' +
								N''''' ' +
							'), ' +
						'index_name = ' +
							'REPLACE ' +
							'( ' +
								'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
								'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
								'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'i.name COLLATE Latin1_General_Bin2, ' +
									'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
									'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
									'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
								'NCHAR(0), ' +
								N''''' ' +
							'), ' +
						'schema_name = ' +
							'REPLACE ' +
							'( ' +
								'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
								'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
								'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									's.name COLLATE Latin1_General_Bin2, ' +
									'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
									'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
									'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
								'NCHAR(0), ' +
								N''''' ' +
							'), ' +
						'principal_name = ' + 
							'REPLACE ' +
							'( ' +
								'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
								'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
								'REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( ' +
									'dp.name COLLATE Latin1_General_Bin2, ' +
									'NCHAR(31),N''?''),NCHAR(30),N''?''),NCHAR(29),N''?''),NCHAR(28),N''?''),NCHAR(27),N''?''),NCHAR(26),N''?''),NCHAR(25),N''?''),NCHAR(24),N''?''),NCHAR(23),N''?''),NCHAR(22),N''?''), ' +
									'NCHAR(21),N''?''),NCHAR(20),N''?''),NCHAR(19),N''?''),NCHAR(18),N''?''),NCHAR(17),N''?''),NCHAR(16),N''?''),NCHAR(15),N''?''),NCHAR(14),N''?''),NCHAR(12),N''?''), ' +
									'NCHAR(11),N''?''),NCHAR(8),N''?''),NCHAR(7),N''?''),NCHAR(6),N''?''),NCHAR(5),N''?''),NCHAR(4),N''?''),NCHAR(3),N''?''),NCHAR(2),N''?''),NCHAR(1),N''?''), ' +
								'NCHAR(0), ' +
								N''''' ' +
							') ' +
					'FROM #locks AS l ' +
					'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.allocation_units AS au ON ' +
						'au.allocation_unit_id = l.allocation_unit_id ' +
					'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.partitions AS p ON ' +
						'p.hobt_id = ' +
							'COALESCE ' +
							'( ' +
								'l.hobt_id, ' +
								'CASE ' +
									'WHEN au.type IN (1, 3) THEN au.container_id ' +
									'ELSE NULL ' +
								'END ' +
							') ' +
					'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.partitions AS p1 ON ' +
						'l.hobt_id IS NULL ' +
						'AND au.type = 2 ' +
						'AND p1.partition_id = au.container_id ' +
					'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.objects AS o ON ' +
						'o.object_id = COALESCE(l.object_id, p.object_id, p1.object_id) ' +
					'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.indexes AS i ON ' +
						'i.object_id = COALESCE(l.object_id, p.object_id, p1.object_id) ' +
						'AND i.index_id = COALESCE(l.index_id, p.index_id, p1.index_id) ' +
					'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.schemas AS s ON ' +
						's.schema_id = COALESCE(l.schema_id, o.schema_id) ' +
					'LEFT OUTER JOIN ' + QUOTENAME(@database_name) + '.sys.database_principals AS dp ON ' +
						'dp.principal_id = l.principal_id ' +
					'WHERE ' +
						'l.database_name = @database_name ' +
					'OPTION (KEEPFIXED PLAN); ';
					
				EXEC sp_executesql
					@sql_n,
					N'@database_name sysname',
					@database_name;
			END TRY
			BEGIN CATCH;
				UPDATE #locks
				SET
					query_error = 
						REPLACE
						(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								CONVERT
								(
									NVARCHAR(MAX), 
									ERROR_MESSAGE() COLLATE Latin1_General_Bin2
								),
								NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
								NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
								NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
							NCHAR(0),
							N''
						)
				WHERE 
					database_name = @database_name
				OPTION (KEEPFIXED PLAN);
			END CATCH;

			FETCH NEXT FROM locks_cursor
			INTO
				@database_name;
		END;

		CLOSE locks_cursor;
		DEALLOCATE locks_cursor;

		CREATE CLUSTERED INDEX IX_SRD ON #locks (session_id, request_id, database_name);

		UPDATE s
		SET 
			s.locks =
			(
				SELECT 
					REPLACE
					(
						REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
						REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
						REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
							CONVERT
							(
								NVARCHAR(MAX), 
								l1.database_name COLLATE Latin1_General_Bin2
							),
							NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
							NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
							NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
						NCHAR(0),
						N''
					) AS [Database/@name],
					MIN(l1.query_error) AS [Database/@query_error],
					(
						SELECT 
							l2.request_mode AS [Lock/@request_mode],
							l2.request_status AS [Lock/@request_status],
							COUNT(*) AS [Lock/@request_count]
						FROM #locks AS l2
						WHERE 
							l1.session_id = l2.session_id
							AND l1.request_id = l2.request_id
							AND l2.database_name = l1.database_name
							AND l2.resource_type = 'DATABASE'
						GROUP BY
							l2.request_mode,
							l2.request_status
						FOR XML
							PATH(''),
							TYPE
					) AS [Database/Locks],
					(
						SELECT
							COALESCE(l3.object_name, '(null)') AS [Object/@name],
							l3.schema_name AS [Object/@schema_name],
							(
								SELECT
									l4.resource_type AS [Lock/@resource_type],
									l4.page_type AS [Lock/@page_type],
									l4.index_name AS [Lock/@index_name],
									CASE 
										WHEN l4.object_name IS NULL THEN l4.schema_name
										ELSE NULL
									END AS [Lock/@schema_name],
									l4.principal_name AS [Lock/@principal_name],
									l4.resource_description AS [Lock/@resource_description],
									l4.request_mode AS [Lock/@request_mode],
									l4.request_status AS [Lock/@request_status],
									SUM(l4.request_count) AS [Lock/@request_count]
								FROM #locks AS l4
								WHERE 
									l4.session_id = l3.session_id
									AND l4.request_id = l3.request_id
									AND l3.database_name = l4.database_name
									AND COALESCE(l3.object_name, '(null)') = COALESCE(l4.object_name, '(null)')
									AND COALESCE(l3.schema_name, '') = COALESCE(l4.schema_name, '')
									AND l4.resource_type <> 'DATABASE'
								GROUP BY
									l4.resource_type,
									l4.page_type,
									l4.index_name,
									CASE 
										WHEN l4.object_name IS NULL THEN l4.schema_name
										ELSE NULL
									END,
									l4.principal_name,
									l4.resource_description,
									l4.request_mode,
									l4.request_status
								FOR XML
									PATH(''),
									TYPE
							) AS [Object/Locks]
						FROM #locks AS l3
						WHERE 
							l3.session_id = l1.session_id
							AND l3.request_id = l1.request_id
							AND l3.database_name = l1.database_name
							AND l3.resource_type <> 'DATABASE'
						GROUP BY 
							l3.session_id,
							l3.request_id,
							l3.database_name,
							COALESCE(l3.object_name, '(null)'),
							l3.schema_name
						FOR XML
							PATH(''),
							TYPE
					) AS [Database/Objects]
				FROM #locks AS l1
				WHERE
					l1.session_id = s.session_id
					AND l1.request_id = s.request_id
					AND l1.start_time IN (s.start_time, s.last_request_start_time)
				GROUP BY 
					l1.session_id,
					l1.request_id,
					l1.database_name
				FOR XML
					PATH(''),
					TYPE
			)
		FROM #SysProcesses s
		OPTION (KEEPFIXED PLAN);
	END


	-- Get Blocking Tree Information
	;WITH T_BLOCKERS AS
	(
		-- Find block Leaders
		SELECT	[dd hh:mm:ss], [collection_time_utc], [session_id], 
				[sql_text] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(COALESCE([sql_command],[sql_text]) AS VARCHAR(MAX)),char(13),''),CHAR(10),''),'<?query --',''),'--?>',''), 
				command, [login_name], wait_type, r.wait_time, wait_resource_type, [blocking_session_id], null as [blocked_session_count],
				[status], open_tran, [host_name], [database_name], [program_name], r.plan_handle,r.statement_start_offset, r.statement_end_offset,
				r.cpu, r.[tempdb_allocations], r.[tempdb_current], r.[reads], r.[writes], r.[physical_io], locks,
				[level] = CAST (REPLICATE ('0', 4-LEN (CAST (r.session_id AS VARCHAR))) + CAST (r.session_id AS VARCHAR) AS VARCHAR(1000))
				,[head_blocker] = session_id
		FROM	#SysProcesses AS r
		WHERE	(ISNULL(r.blocking_session_id,0) = 0 OR ISNULL(r.blocking_session_id,0) = r.session_id)
			AND EXISTS (SELECT * FROM #SysProcesses AS R2 WHERE R2.[collection_time_utc] = r.[collection_time_utc] AND ISNULL(R2.blocking_session_id,0) = r.session_id AND ISNULL(R2.blocking_session_id,0) <> R2.session_id)
		--	
		UNION ALL
		--
		SELECT	r.[dd hh:mm:ss], r.[collection_time_utc], r.[session_id], 
				[sql_text] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(COALESCE(r.[sql_command],r.[sql_text]) AS VARCHAR(MAX)),char(13),''),CHAR(10),''),'<?query --',''),'--?>',''), 
				r.command, r.[login_name], r.wait_type, r.wait_time, r.wait_resource_type, r.[blocking_session_id], null as [blocked_session_count],
				r.[status], r.open_tran, r.[host_name], r.[database_name], r.[program_name],  r.plan_handle,r.statement_start_offset, r.statement_end_offset,
				r.cpu, r.[tempdb_allocations], r.[tempdb_current], r.[reads], r.[writes], r.[physical_io], r.locks,
				CAST (B.[level] + RIGHT (CAST ((1000 + r.session_id) AS VARCHAR (100)), 4) AS VARCHAR (1000)) AS [level]
				,[head_blocker] = case when B.[head_blocker] is null then B.session_id else B.[head_blocker] end
		FROM	#SysProcesses AS r
		INNER JOIN 
				T_BLOCKERS AS B
			ON	r.[collection_time_utc] = B.[collection_time_utc]
			AND	r.blocking_session_id = B.session_id
		WHERE	r.blocking_session_id <> r.session_id
	)
	,T_BlockingTree AS
	(
		SELECT	[dd hh:mm:ss], 
				[blocking_tree] = N'    ' + REPLICATE (N'|         ', LEN ([level])/4 - 1) 
								+	CASE	WHEN (LEN([level])/4 - 1) = 0
											THEN 'HEAD -  '
											ELSE '|------  ' 
									END
								+	CAST (r.session_id AS NVARCHAR (10)) + N' ' + (CASE WHEN LEFT(r.[sql_text],1) = '(' THEN SUBSTRING(r.[sql_text],CHARINDEX('exec',r.[sql_text]),LEN(r.[sql_text]))  ELSE r.[sql_text] END),
				[session_id], [blocking_session_id], 
				--w.lock_text,
				[head_blocker],		
				[blocked_session_count] = COUNT(*) OVER (PARTITION BY [head_blocker]),
				[sql_commad] = CONVERT(XML, '<?query -- '+char(13)
								+ (CASE WHEN LEFT([sql_text],1) = '(' THEN SUBSTRING([sql_text],CHARINDEX('exec',[sql_text]),LEN([sql_text]))  ELSE [sql_text] END)
								+ char(13)+'--?>')
				,command, [login_name], [program_name], [database_name], wait_type, wait_time, wait_resource_type, status, 
				r.open_tran, r.cpu, r.[reads], r.[writes], r.[physical_io],  r.plan_handle,r.statement_start_offset, r.statement_end_offset
				,[host_name] ,locks
				,[level]
		FROM	T_BLOCKERS AS r
	)
	SELECT	[dd hh:mm:ss], [blocking_tree], [blocked_count] = case when session_id = [head_blocker] then [blocked_session_count] else null end, 
			[sql_commad], [command], [login_name], [program_name], [database_name], [wait_type], [wait_time], [status], 
			[open_tran], [cpu], [reads], [writes], [physical_io], [host_name], [level], locks
			,sql_plan = CAST(sqp.query_plan AS xml) 
			,session_id, blocking_session_id, [head_blocker], cast(0 as tinyint) as is_consistently_blocked
			,collection_time_utc = @current_time_utc
	INTO #Blockings
	FROM T_BlockingTree AS bt
	OUTER APPLY sys.dm_exec_text_query_plan(bt.plan_handle, bt.statement_start_offset, bt.statement_end_offset) as sqp
	ORDER BY [blocked_session_count] DESC, [level] ASC;

	IF OBJECT_ID('dbo.blocking_report') IS NOT NULL
	BEGIN
			INSERT dbo.blocking_report
			SELECT * from #Blockings
	END
	ELSE
	BEGIN
			SELECT *
			INTO dbo.blocking_report
			FROM #Blockings
	END

	IF NOT EXISTS (select * from sys.indexes i where i.object_id = OBJECT_ID('dbo.blocking_report') and name = 'ci_blocking_report')
		CREATE CLUSTERED INDEX ci_blocking_report ON dbo.blocking_report (collection_time_utc, [level]);

	--select * from dbo.blocking_report

	DECLARE @blocking_reference_statement nvarchar(max);
	DECLARE @consistent_blocking_reference_statement nvarchar(max);

	set @blocking_reference_statement = "/* Find blocking report by replacing @collection_time_utc variable value */
	use ["+DB_NAME()+"];
	declare @collection_time_utc datetime = '"+CONVERT(varchar,@current_time_utc,121)+"';
	select [dd hh:mm:ss], [blocking_tree], [blocked_count], [sql_commad], [command], [login_name], [program_name], 
			[database_name], [wait_type], [wait_time], [is_consistently_blocked], [status], locks,
			[open_tran], [cpu], [reads], [writes], [physical_io], [host_name], sql_plan, session_id, collection_time_utc 
	from dbo.blocking_report 
	where collection_time_utc = @collection_time_utc
	order by collection_time_utc, [level] ASC;
	";
	--print @blocking_reference_statement
	set @consistent_blocking_reference_statement = "/* Find blocking report for consistent blocking by replacing @collection_time_utc variable value */
	use ["+DB_NAME()+"];
	declare @collection_time_utc datetime = '"+CONVERT(varchar,@current_time_utc,121)+"'
	select [dd hh:mm:ss], [blocking_tree], [blocked_count], [sql_commad], [command], [login_name], [program_name], 
			[database_name], [wait_type], [wait_time], [is_consistently_blocked], [status], locks,
			[open_tran], [cpu], [reads], [writes], [physical_io], [host_name], sql_plan, session_id, blocking_session_id, head_blocker,
			collection_time_utc 
	from dbo.blocking_report as br
	where collection_time_utc = @collection_time_utc
		and (	[is_consistently_blocked] = 1 
			or	head_blocker in (select i.head_blocker from dbo.blocking_report as i 
								where i.collection_time_utc = @collection_time_utc and i.[is_consistently_blocked] = 1)
			)
	order by collection_time_utc, [level] ASC;
	"
	--print @consistent_blocking_reference_statement

	-- Check for consistent blocking
	if exists (select * from dbo.blocking_report where collection_time_utc = @current_time_utc and blocking_session_id <> 0 and wait_time >= 1000*60*@consistent_blocking_threshold_minutes) -- if wait_time more than @consistent_blocking_threshold_minutes
	begin
		-- blocked sessions at current time
		select * into #snapshot_current from dbo.blocking_report 
			where collection_time_utc = @current_time_utc and blocking_session_id <> 0 
				and wait_time >= 1000*60*@consistent_blocking_threshold_minutes

		-- match blocked sessions from snapshot prior to @consistent_blocking_threshold_minutes
		select c.* into #snapshot_previous 
		from #snapshot_current as c
		join dbo.blocking_report as p 
			on c.session_id = p.session_id and c.database_name = p.database_name and c.login_name = p.login_name 
				and c.program_name = p.program_name and c.host_name = p.host_name and c.blocking_session_id = p.blocking_session_id
		where p.collection_time_utc = (select max(b.collection_time_utc) from dbo.blocking_report b where b.collection_time_utc <= DATEADD(minute,-@consistent_blocking_threshold_minutes,@current_time_utc));

		update br set is_consistently_blocked = 1
		from #snapshot_previous as sp
		join dbo.blocking_report as br on br.collection_time_utc = sp.collection_time_utc and sp.session_id = br.session_id;
	end

	-- Validate - Report when more than @concurrent_blocking_threshold number of blocking sessions
	if(select count(*) from dbo.blocking_report where collection_time_utc = @current_time_utc) > 0 and APP_NAME() = 'Microsoft SQL Server Management Studio - Query'
	exec (@blocking_reference_statement)

end

-- Compute blocking counters
select	SERVERPROPERTY('MachineName') AS server_name,
		CONVERT(varchar,@current_time_utc,121) as blocking_time_utc, 
		count(*) as blocking_sessions_count, 
		count(blocked_count) as head_blockers_count, 
		isnull(sum(case when blocked_count is null then 1 else 0 end),0) as blocked_count,		
		isnull(sum(is_consistently_blocked),0) as consistently_blocked_session_count,
		@blocking_reference_statement as blocking_reference_statement,
		@consistent_blocking_reference_statement as consistent_blocking_reference_statement
from dbo.blocking_report
where collection_time_utc = @current_time_utc;

-- drop table DBA.dbo.blocking_report

