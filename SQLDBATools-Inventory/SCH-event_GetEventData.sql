USE DBA
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[event_GetEventData]
(
	@eventName sysname = NULL,
	@beginDateTime datetime2 = '2016-06-07 00:00:01',
	@endDateTime datetime2 = NULL,
	@errorNumberIN varchar(MAX) = '',
	@errorNumberNOT_IN varchar(MAX) = '',
	@errorMessageLIKE varchar(2000) = '',
	@client_app_NOT_LIKE varchar(2000) = '',
	@xmlOnly bit = 0
)
AS
BEGIN
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	SET NOCOUNT ON;

	DECLARE @XML xml;

	SET @endDateTime = ISNULL(@endDateTime,GETDATE())

	--GET PATH TO EVENT FILE -----------------------------
	DECLARE @filePath sysname

	SELECT @filePath = n.value('(@name)[1]','varchar(255)')
	FROM (SELECT CAST(t.target_data AS XML) target_data
			FROM sys.dm_xe_sessions s
				INNER JOIN sys.dm_xe_session_targets t ON t.event_session_address = s.address
			WHERE s.name = CASE WHEN @eventName = 'BlockingReport' THEN 'Blocking' ELSE @eventName END
				AND t.target_name = N'event_file') AS tab
		CROSS APPLY [target_data].[nodes]('EventFileTarget/File') AS [q] ([n]);


	SET @filePath = LEFT(@filePath,LEN(@filePath) - CHARINDEX('_',REVERSE(@filePath))) + '_*xel'
	------------------------------------------------------

	IF @eventName IS NULL
	BEGIN
		SELECT 'Blocking'	UNION ALL
		SELECT 'Deadlocks'	UNION ALL
		SELECT 'DurationGT25Seconds'	UNION ALL
		SELECT 'Errors'	UNION ALL
		SELECT 'TimeOuts' UNION ALL
		SELECT 'BlockingReport'
	END
	ELSE IF @eventName = 'Blocking' OR @eventName = 'BlockingReport'
	-- BLOCKING ------------------------------------------
	BEGIN
		IF OBJECT_ID('tempdb..#BLOCKING') IS NOT NULL
			DROP TABLE #BLOCKING;
		CREATE TABLE #BLOCKING
		(
			[TimeStamp] datetime,
			[BlockDuration] decimal(10,2),
			[IsBlocked] bit,
			SPID int,
			[Blocking_SPID] int,
			[Status] varchar(255),
			[ProcessId] varchar(255),
			WaitResource varchar(255),
			WaitTime bigint,
			ClientApp varchar(255),
			HostName varchar(255),
			LoginName varchar(255),
			IsolationLevel varchar(255),
			[dbName] varchar(255),
			[Buffered_Input] varchar(MAX),
			TransactionName varchar(255),
			LastTranStarted varchar(255),
			LockMode varchar(255),
			LastBatchStarted datetime,
			LastBatchCompleted datetime,
			xmlData xml
		)


		DECLARE curXML CURSOR FAST_FORWARD LOCAL FOR
			SELECT CAST(event_data AS XML) FROM sys.fn_xe_file_target_read_file(@filePath,NULL,NULL,NULL)
		OPEN curXML
		FETCH NEXT FROM curXML INTO @XML

		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF (@XML.value('(/event/@timestamp)[1]','datetime') + GETDATE() - GETUTCDATE() BETWEEN @beginDateTime AND @endDateTime)
			BEGIN
				INSERT INTO #BLOCKING([TimeStamp],[BlockDuration],[IsBlocked],SPID,[Blocking_SPID],[Status],[ProcessId],WaitResource,WaitTime,ClientApp,HostName,
										LoginName,IsolationLevel,[dbName],[Buffered_Input],TransactionName,LastTranStarted,LockMode,LastBatchStarted,LastBatchCompleted,xmlData)
				SELECT	@XML.value('(/event/@timestamp)[1]','datetime') + GETDATE() - GETUTCDATE() AS [TimeStamp],
						CONVERT(decimal(10,2),@XML.value('(/event/data/value)[1]','bigint')/1000000.0) AS [BlockDuration],
						CONVERT(bit,1) AS [IsBlocked],
						blocked.value('@spid','int') AS SPID,
						@XML.value('(event/data[@name="blocked_process"]/value/blocked-process-report/blocking-process/process/@spid)[1]','int') AS [Blocking_SPID],
						blocked.value('@status','varchar(255)') AS [Status],
						blocked.value('@id','varchar(255)') AS [ProcessId],
						blocked.value('@waitresource','varchar(255)') AS WaitResource,
						blocked.value('@waittime','bigint') AS WaitTime,
						blocked.value('@clientapp','varchar(255)') AS ClientApp,
						blocked.value('@hostname','varchar(255)') AS HostName,
						blocked.value('@loginname','varchar(255)') AS LoginName,
						blocked.value('@isolationlevel','varchar(255)') AS IsolationLevel,
						DB_NAME(blocked.value('@currentdb','int')) AS [dbName],
						blocked.value('(inputbuf)[1]','varchar(MAX)') AS [Buffered_Input],	
						blocked.value('@transactionname','varchar(255)') AS TransactionName,
						blocked.value('@lasttranstarted','varchar(255)') AS LastTranStarted,
						blocked.value('@lockMode','varchar(255)') AS LockMode,
						blocked.value('@lastbatchstarted','datetime') AS LastBatchStarted,
						blocked.value('@lastbatchcompleted','datetime') AS LastBatchCompleted,
						@XML AS xmlData
				FROM @XML.nodes('event/data[@name="blocked_process"]/value/blocked-process-report/blocked-process/process') AS ref(blocked)
				WHERE LEN(ISNULL(@client_app_NOT_LIKE,'')) = 0 OR blocked.value('@clientapp','varchar(255)') NOT LIKE '%' + ISNULL(@client_app_NOT_LIKE,'') + '%'
					UNION ALL
				SELECT	@XML.value('(/event/@timestamp)[1]','datetime') + GETDATE() - GETUTCDATE() AS [TimeStamp],
						NULL AS [BlockDuration],
						CONVERT(bit,0) AS [IsBlocked],
						blocked.value('@spid','int') AS SPID,
						NULL AS [Blocking_SPID],
						blocked.value('@status','varchar(255)') AS [Status],
						'' AS [ProcessId],
						blocked.value('@waitresource','varchar(255)') AS WaitResource,
						blocked.value('@waittime','bigint') AS WaitTime,
						blocked.value('@clientapp','varchar(255)') AS ClientApp,
						blocked.value('@hostname','varchar(255)') AS HostName,
						blocked.value('@loginname','varchar(255)') AS LoginName,
						blocked.value('@isolationlevel','varchar(255)') AS IsolationLevel,
						DB_NAME(blocked.value('@currentdb','int')) AS [dbName],
						blocked.value('(inputbuf)[1]','varchar(MAX)') AS [Buffered_Input],
						'' AS TransactionName,
						'' AS LastTranStarted,
						'' AS LockMode,
						blocked.value('@lastbatchstarted','datetime') AS LastBatchStarted,
						blocked.value('@lastbatchcompleted','datetime') AS LastBatchCompleted,
						@XML AS xmlData
				FROM @XML.nodes('event/data[@name="blocked_process"]/value/blocked-process-report/blocking-process/process') AS ref(blocked)
				WHERE LEN(ISNULL(@client_app_NOT_LIKE,'')) = 0 OR blocked.value('@clientapp','varchar(255)') NOT LIKE '%' + ISNULL(@client_app_NOT_LIKE,'') + '%'
			END
			FETCH NEXT FROM curXML INTO @XML
		END
		DEALLOCATE curXML
		
		------------------------------------------------------------
		IF @xmlOnly = 1
			SELECT xmlData FROM #BLOCKING
		ELSE IF @eventName = 'Blocking'
		BEGIN
			DECLARE @TimeStamp datetime;

			DECLARE curBlocking CURSOR FAST_FORWARD LOCAL FOR
				SELECT DISTINCT [TimeStamp] FROM #BLOCKING ORDER BY [TimeStamp]
			OPEN curBlocking
			FETCH NEXT FROM curBlocking INTO @TimeStamp

			WHILE @@FETCH_STATUS = 0
			BEGIN
				SELECT [TimeStamp],MAX([BlockDuration]) AS [BlockDuration],MAX(CONVERT(int,[IsBlocked])) AS [IsBlocked],SPID,MAX([Blocking_SPID]) AS [Blocking_SPID],
					MAX([Status]) AS [Status],MAX([ProcessId]) AS [ProcessId],MAX(WaitResource) AS WaitResource,MAX(WaitTime) AS WaitTime,MAX(ClientApp) AS ClientApp,
					MAX(HostName) AS HostName,MAX(LoginName) AS LoginName,MAX(IsolationLevel) AS IsolationLevel,MAX([dbName]) AS [dbName],
					MAX([Buffered_Input]) AS [Buffered_Input],MAX(TransactionName) AS TransactionName,MAX(LastTranStarted) AS LastTranStarted,MAX(LockMode) AS LockMode,
					MAX(LastBatchStarted) AS LastBatchStarted,MAX(LastBatchCompleted) AS LastBatchCompleted
				FROM #BLOCKING
				WHERE [TimeStamp] = @TimeStamp
				GROUP BY [TimeStamp],SPID

				FETCH NEXT FROM curBlocking INTO @TimeStamp
			END
			DEALLOCATE curBlocking
		END
		ELSE
		BEGIN
			SELECT RANK() OVER(ORDER BY [TimeStamp]) AS BlockGrouping,
				[TimeStamp],MAX([BlockDuration]) AS [BlockDuration],MAX(CONVERT(int,[IsBlocked])) AS [IsBlocked],SPID,MAX([Blocking_SPID]) AS [Blocking_SPID],
				MAX([Status]) AS [Status],MAX([ProcessId]) AS [ProcessId],MAX(WaitResource) AS WaitResource,MAX(WaitTime) AS WaitTime,MAX(ClientApp) AS ClientApp,
				MAX(HostName) AS HostName,MAX(LoginName) AS LoginName,MAX(IsolationLevel) AS IsolationLevel,MAX([dbName]) AS [dbName],
				MAX([Buffered_Input]) AS [Buffered_Input],MAX(TransactionName) AS TransactionName,MAX(LastTranStarted) AS LastTranStarted,MAX(LockMode) AS LockMode,
				MAX(LastBatchStarted) AS LastBatchStarted,MAX(LastBatchCompleted) AS LastBatchCompleted
			FROM #BLOCKING
			GROUP BY [TimeStamp],SPID
		END
	END
	------------------------------------------------------
	ELSE IF @eventName = 'Deadlocks'
	-- DEADLOCKS -----------------------------------------
	BEGIN
		-- CREATE TEMP TABLES ---------------------------------------
		IF OBJECT_ID('tempdb..#VICTIM') IS NOT NULL
			DROP TABLE #VICTIM;
		CREATE TABLE #VICTIM(ProcessId varchar(255))

		IF OBJECT_ID('tempdb..#KEY_LOCK') IS NOT NULL
			DROP TABLE #KEY_LOCK;
		CREATE TABLE #KEY_LOCK(HObtId bigint,DatabaseName varchar(255),ObjectName varchar(255),IndexName varchar(255),ID varchar(255),OwnerMode varchar(255))

		IF OBJECT_ID('tempdb..#PAGE_LOCK') IS NOT NULL
			DROP TABLE #PAGE_LOCK;
		CREATE TABLE #PAGE_LOCK(FileId bigint,PageId bigint,DatabaseName varchar(255),SubResource nvarchar(255),ObjectName varchar(255),AssociatedObjectId varchar(255),ID varchar(255),OwnerMode varchar(255))

		IF OBJECT_ID('tempdb..#PARTITION_LOCK') IS NOT NULL
			DROP TABLE #PARTITION_LOCK;
		CREATE TABLE #PARTITION_LOCK(LockPartition bigint,ObjectId bigint,DatabaseName varchar(255),SubResource nvarchar(255),ObjectName varchar(255),AssociatedObjectId varchar(255),ID varchar(255),OwnerMode varchar(255))

		IF OBJECT_ID('tempdb..#OWNER') IS NOT NULL
			DROP TABLE #OWNER;
		CREATE TABLE #OWNER(HObtId varchar(255),RequestType varchar(20),Mode varchar(20),ProcessId varchar(255))

		IF OBJECT_ID('tempdb..#OWNER2') IS NOT NULL
			DROP TABLE #OWNER2;
		CREATE TABLE #OWNER2(Id varchar(255),WaitType varchar(255),nodeId bigint,ProcessId varchar(255),IsOwner varchar(20))

		IF OBJECT_ID('tempdb..#PROCESS') IS NOT NULL
			DROP TABLE #PROCESS;
		CREATE TABLE #PROCESS(ProcessId varchar(255),WaitResource varchar(255),TransactionName varchar(255),LockMode varchar(255),[Status] varchar(255),TranCount int,
								ClientApp varchar(255),HostName varchar(255),LoginName varchar(255),IsolationLevel varchar(255),CurrentDB varchar(255),ProcName varchar(255),
								SQLHandle varchar(255),StackBuffer varchar(MAX),InputBuffer varchar(MAX))
		-------------------------------------------------------------


		DECLARE curXML CURSOR FAST_FORWARD LOCAL FOR
			SELECT CAST(event_data AS XML) FROM sys.fn_xe_file_target_read_file(@filePath,NULL,NULL,NULL)
		OPEN curXML
		FETCH NEXT FROM curXML INTO @XML

		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF (@XML.value('(/event/@timestamp)[1]','datetime') + GETDATE() - GETUTCDATE() BETWEEN @beginDateTime AND @endDateTime)
			BEGIN
				DELETE #VICTIM
				DELETE #KEY_LOCK
				DELETE #PAGE_LOCK
				DELETE #PARTITION_LOCK
				DELETE #OWNER
				DELETE #OWNER2
				DELETE #PROCESS

				IF @xmlOnly = 1
					SELECT @XML
				ELSE
				BEGIN
					-- GET PROCESS LIST -----------------------------------------
					INSERT INTO #PROCESS(ProcessId,WaitResource,TransactionName,LockMode,[Status],TranCount,ClientApp,HostName,LoginName,IsolationLevel,CurrentDB,ProcName,SQLHandle,StackBuffer,InputBuffer)
					SELECT	deadlock.value('@id','varchar(255)') AS ProcessId,
							deadlock.value('@waitresource','varchar(255)') AS WaitResource,
							deadlock.value('@transactionname','varchar(255)') AS TransactionName,
							deadlock.value('@lockMode','varchar(255)') AS LockMode,
							deadlock.value('@status','varchar(255)') AS [Status],
							deadlock.value('@trancount','int') AS TranCount,
							deadlock.value('@clientapp','varchar(255)') AS ClientApp,
							deadlock.value('@hostname','varchar(255)') AS HostName,
							deadlock.value('@loginname','varchar(255)') AS LoginName,
							deadlock.value('@isolationlevel','varchar(255)') AS IsolationLevel,
							DB_NAME(deadlock.value('@currentdb','int')) AS CurrentDB,
							deadlock.value('(executionStack/frame/@procname)[1]','varchar(255)') AS ProcName,
							deadlock.value('(executionStack/frame/@sqlhandle)[1]','varchar(255)') AS SQLHandle,
							deadlock.value('(executionStack/frame)[1]','varchar(MAX)') AS StackBuffer,
							deadlock.value('inputbuf[1]','varchar(MAX)') AS InputBuffer
					FROM @XML.nodes('event/data/value/deadlock/process-list/process') AS ref(deadlock)
					WHERE LEN(ISNULL(@client_app_NOT_LIKE,'')) = 0 OR deadlock.value('@clientapp','varchar(255)') NOT LIKE '%' + ISNULL(@client_app_NOT_LIKE,'') + '%'
					-------------------------------------------------------------

					-- GET VICTIMS ----------------------------------------------
					INSERT INTO #VICTIM(ProcessId)
					SELECT deadlock.value('@id','varchar(255)') AS ProcessId
					FROM @XML.nodes('event/data/value/deadlock/victim-list/victimProcess') AS ref(deadlock)
					-------------------------------------------------------------

					IF @XML.value('(event/data/value/deadlock/resource-list/exchangeEvent/@id)[1]','varchar(255)') IS NOT NULL
					BEGIN
						-- GET OWNER/WAITER -----------------------------------------
						INSERT INTO #OWNER2(Id,WaitType,nodeId,ProcessId,IsOwner)
						SELECT	keylock.value('@id','varchar(255)') AS Id,
								keylock.value('@WaitType','varchar(255)') AS WaitType,
								keylock.value('@nodeId','bigint') AS WaitType,
								deadlock.value('@id','varchar(255)') AS ProcessId,
								'TRUE' AS IsOwner
						FROM @XML.nodes('event/data/value/deadlock/resource-list/exchangeEvent') AS ref(keylock)
							CROSS APPLY keylock.nodes('owner-list/owner') AS ref2(deadlock)

							UNION ALL

						SELECT	keylock.value('@id','varchar(255)') AS Id,
								keylock.value('@WaitType','varchar(255)') AS WaitType,
								keylock.value('@nodeId','bigint') AS WaitType,
								deadlock.value('@id','varchar(255)') AS ProcessId,
								'TRUE' AS IsOwner
						FROM @XML.nodes('event/data/value/deadlock/resource-list/exchangeEvent') AS ref(keylock)
							CROSS APPLY keylock.nodes('waiter-list/waiter') AS ref2(deadlock)
						-------------------------------------------------------------
					END
					ELSE IF @XML.value('(event/data/value/deadlock/resource-list/keylock/@hobtid)[1]','bigint') IS NOT NULL
					BEGIN
						-- GET LOCK LIST --------------------------------------------
						INSERT INTO #KEY_LOCK(HObtId,DatabaseName,ObjectName,IndexName,ID,OwnerMode)
						SELECT	deadlock.value('@hobtid','bigint') AS HObtId,
								DB_NAME(deadlock.value('@dbid','int')) AS DatabaseName,
								deadlock.value('@objectname','varchar(255)') AS ObjectName,
								deadlock.value('@indexname','varchar(255)') AS IndexName,
								deadlock.value('@id','varchar(255)') AS ID,
								deadlock.value('@mode','varchar(255)') AS OwnerMode
						FROM @XML.nodes('event/data/value/deadlock/resource-list/keylock') AS ref(deadlock)
						-------------------------------------------------------------

						-- GET OWNER/WAITER -----------------------------------------
						INSERT INTO #OWNER(HObtId,ProcessId,Mode,RequestType)
						SELECT	keylock.value('@hobtid','bigint') AS HObtId,
								deadlock.value('@id','varchar(255)') AS id,
								deadlock.value('@mode','varchar(255)') AS Mode,
								deadlock.value('@requestType','varchar(255)') AS RequestType
						FROM @XML.nodes('event/data/value/deadlock/resource-list/keylock') AS ref(keylock)
							CROSS APPLY keylock.nodes('owner-list/owner') AS ref2(deadlock)

							UNION ALL

						SELECT	keylock.value('@hobtid','bigint') AS HObtId,
								deadlock.value('@id','varchar(255)') AS id,
								deadlock.value('@mode','varchar(255)') AS Mode,
								deadlock.value('@requestType','varchar(255)') AS RequestType
						FROM @XML.nodes('event/data/value/deadlock/resource-list/keylock') AS ref(keylock)
							CROSS APPLY keylock.nodes('waiter-list/waiter') AS ref2(deadlock)
						-------------------------------------------------------------
					END
					ELSE IF @XML.value('(event/data/value/deadlock/resource-list/pagelock/@fileid)[1]','bigint') IS NOT NULL
					BEGIN
						-- GET LOCK LIST --------------------------------------------
						INSERT INTO #PAGE_LOCK(FileId,PageId,DatabaseName,SubResource,ObjectName,AssociatedObjectId,ID,OwnerMode)
						SELECT	deadlock.value('@fileid','bigint') AS FileId,
								deadlock.value('@pageid','bigint') AS PageId,
								DB_NAME(deadlock.value('@dbid','int')) AS DatabaseName,
								deadlock.value('@subresource','nvarchar(255)') AS SubResource,
								deadlock.value('@objectname','varchar(255)') AS ObjectName,
								deadlock.value('@associatedObjectId','varchar(255)') AS AssociatedObjectId,
								deadlock.value('@id','varchar(255)') AS ID,
								deadlock.value('@mode','varchar(255)') AS OwnerMode
						FROM @XML.nodes('event/data/value/deadlock/resource-list/pagelock') AS ref(deadlock)
						-------------------------------------------------------------

						-- GET OWNER/WAITER -----------------------------------------
						INSERT INTO #OWNER(HObtId,ProcessId,Mode,RequestType)
						SELECT	keylock.value('@id','varchar(255)') AS HObtId,
								deadlock.value('@id','varchar(255)') AS id,
								deadlock.value('@mode','varchar(255)') AS Mode,
								deadlock.value('@requestType','varchar(255)') AS RequestType
						FROM @XML.nodes('event/data/value/deadlock/resource-list/pagelock') AS ref(keylock)
							CROSS APPLY keylock.nodes('owner-list/owner') AS ref2(deadlock)

							UNION ALL

						SELECT	keylock.value('@id','varchar(255)') AS HObtId,
								deadlock.value('@id','varchar(255)') AS id,
								deadlock.value('@mode','varchar(255)') AS Mode,
								deadlock.value('@requestType','varchar(255)') AS RequestType
						FROM @XML.nodes('event/data/value/deadlock/resource-list/pagelock') AS ref(keylock)
							CROSS APPLY keylock.nodes('waiter-list/waiter') AS ref2(deadlock)
						-------------------------------------------------------------
					END
					ELSE IF @XML.value('(event/data/value/deadlock/resource-list/objectlock/@lockPartition)[1]','bigint') IS NOT NULL
					BEGIN
						-- GET LOCK LIST --------------------------------------------
						INSERT INTO #PARTITION_LOCK(LockPartition,ObjectId,DatabaseName,SubResource,ObjectName,AssociatedObjectId,ID,OwnerMode)
						SELECT	deadlock.value('@lockPartition','bigint') AS FileId,
								deadlock.value('@objid','bigint') AS PageId,
								DB_NAME(deadlock.value('@dbid','int')) AS DatabaseName,
								deadlock.value('@subresource','nvarchar(255)') AS SubResource,
								deadlock.value('@objectname','varchar(255)') AS ObjectName,
								deadlock.value('@associatedObjectId','varchar(255)') AS AssociatedObjectId,
								deadlock.value('@id','varchar(255)') AS ID,
								deadlock.value('@mode','varchar(255)') AS OwnerMode
						FROM @XML.nodes('event/data/value/deadlock/resource-list/objectlock') AS ref(deadlock)
						-------------------------------------------------------------

						-- GET OWNER/WAITER -----------------------------------------
						INSERT INTO #OWNER(HObtId,ProcessId,Mode,RequestType)
						SELECT	keylock.value('@id','varchar(255)') AS HObtId,
								deadlock.value('@id','varchar(255)') AS id,
								deadlock.value('@mode','varchar(255)') AS Mode,
								deadlock.value('@requestType','varchar(255)') AS RequestType
						FROM @XML.nodes('event/data/value/deadlock/resource-list/objectlock') AS ref(keylock)
							CROSS APPLY keylock.nodes('owner-list/owner') AS ref2(deadlock)

							UNION ALL

						SELECT	keylock.value('@id','varchar(255)') AS HObtId,
								deadlock.value('@id','varchar(255)') AS id,
								deadlock.value('@mode','varchar(255)') AS Mode,
								deadlock.value('@requestType','varchar(255)') AS RequestType
						FROM @XML.nodes('event/data/value/deadlock/resource-list/objectlock') AS ref(keylock)
							CROSS APPLY keylock.nodes('waiter-list/waiter') AS ref2(deadlock)
						-------------------------------------------------------------
					END
					-- DISPLAY RESTULTS -----------------------------------------
					IF EXISTS(SELECT * FROM #OWNER2)
					BEGIN
						SELECT	@XML.value('(/event/@timestamp)[1]','datetime') + GETDATE() - GETUTCDATE() AS [TimeStamp_NoVictim],
								p.ProcessId,p.ProcName,
								o.Id AS ExchangeEvent,o.WaitType,o.nodeId,o.IsOwner,
								p.LockMode,p.StackBuffer,p.InputBuffer,p.SQLHandle,
								p.[Status],p.TranCount,p.IsolationLevel,p.CurrentDB,p.WaitResource,
								p.ClientApp,p.HostName,p.LoginName
						FROM #OWNER2 o
							INNER JOIN #PROCESS p ON p.ProcessId = o.ProcessId
						ORDER BY p.ProcessId
					END
					ELSE IF EXISTS(SELECT * FROM #KEY_LOCK)
					BEGIN
						SELECT	@XML.value('(/event/@timestamp)[1]','datetime') + GETDATE() - GETUTCDATE() AS [TimeStamp_KeyLock],
								l.ObjectName,l.IndexName,l.DatabaseName,
								p.ProcessId,p.ProcName,CASE WHEN v.ProcessId IS NULL THEN 'False' ELSE 'True' END AS [DeadlockVictim],
								l.OwnerMode,o.Mode AS [RequestMode],p.LockMode,
								p.StackBuffer,p.InputBuffer,p.SQLHandle,
								o.RequestType,p.[Status],p.TranCount,p.IsolationLevel,p.CurrentDB,p.WaitResource,
								p.ClientApp,p.HostName,p.LoginName
						FROM #KEY_LOCK l
							INNER JOIN #OWNER o ON o.HObtId = l.HObtId
							INNER JOIN #PROCESS p ON p.ProcessId = o.ProcessId
							LEFT JOIN #VICTIM v ON v.ProcessId = o.ProcessId
						ORDER BY l.HObtId,o.ProcessId
					END
					ELSE IF EXISTS(SELECT * FROM #PAGE_LOCK)
					BEGIN
						SELECT	@XML.value('(/event/@timestamp)[1]','datetime') + GETDATE() - GETUTCDATE() AS [TimeStamp_PageLock],
								l.ObjectName,l.FileId,l.PageId,l.DatabaseName,l.AssociatedObjectId,
								p.ProcessId,p.ProcName,CASE WHEN v.ProcessId IS NULL THEN 'False' ELSE 'True' END AS [DeadlockVictim],
								l.OwnerMode,o.Mode AS [RequestMode],p.LockMode,
								p.StackBuffer,p.InputBuffer,p.SQLHandle,
								o.RequestType,p.[Status],p.TranCount,p.IsolationLevel,p.CurrentDB,p.WaitResource,
								p.ClientApp,p.HostName,p.LoginName
						FROM #PAGE_LOCK l
							INNER JOIN #OWNER o ON o.HObtId = l.ID
							INNER JOIN #PROCESS p ON p.ProcessId = o.ProcessId
							LEFT JOIN #VICTIM v ON v.ProcessId = o.ProcessId
						ORDER BY l.ID,o.ProcessId
					END
					ELSE --IF EXISTS(SELECT * FROM #PARTITION_LOCK)
					BEGIN
						SELECT	@XML.value('(/event/@timestamp)[1]','datetime') + GETDATE() - GETUTCDATE() AS [TimeStamp_PartitionLock],
								l.ObjectName,l.LockPartition,l.ObjectId,l.DatabaseName,l.AssociatedObjectId,
								p.ProcessId,p.ProcName,CASE WHEN v.ProcessId IS NULL THEN 'False' ELSE 'True' END AS [DeadlockVictim],
								l.OwnerMode,o.Mode AS [RequestMode],p.LockMode,
								p.StackBuffer,p.InputBuffer,p.SQLHandle,
								o.RequestType,p.[Status],p.TranCount,p.IsolationLevel,p.CurrentDB,p.WaitResource,
								p.ClientApp,p.HostName,p.LoginName
						FROM #PARTITION_LOCK l
							INNER JOIN #OWNER o ON o.HObtId = l.ID
							INNER JOIN #PROCESS p ON p.ProcessId = o.ProcessId
							LEFT JOIN #VICTIM v ON v.ProcessId = o.ProcessId
						ORDER BY l.ID,o.ProcessId
					END
					-------------------------------------------------------------
				END
			END

			FETCH NEXT FROM curXML INTO @XML
		END
		DEALLOCATE curXML;
	END
	------------------------------------------------------
	ELSE IF @eventName = 'DurationGT25Seconds'
	-- DURATION GREATER THAN 25 Seconds ------------------
	BEGIN
		IF OBJECT_ID('tempdb..#GT25_EVENTS') IS NOT NULL
			DROP TABLE #GT25_EVENTS;
		CREATE TABLE #GT25_EVENTS
		(
			[timestamp] datetime,
			duration decimal(10,2),
			client_app_name varchar(255),
			[statement] varchar(MAX),
			cpu_time decimal(10,2),
			physical_reads bigint,
			logical_reads bigint,
			writes bigint,
			row_count bigint,
			database_name varchar(255),
			[object_name] varchar(255),
			output_parameters varchar(MAX),
			client_hostname varchar(255),
			nt_username varchar(255),
			connection_reset_option bigint,
			connection_reset_option_text varchar(255),
			data_stream varchar(MAX),
			is_system varchar(20),
			plan_handle varchar(255),
			session_id int,
			event_name varchar(50),
			result bigint
		)

		IF @xmlOnly = 1
		BEGIN
			SELECT event_data
			FROM (SELECT CAST(event_data AS XML) event_data
			  FROM sys.fn_xe_file_target_read_file(@filePath,NULL,NULL,NULL)) AS tab
			CROSS APPLY [event_data].[nodes]('event') AS [q] ([n])
			WHERE LEN(ISNULL(@client_app_NOT_LIKE,'')) = 0 OR n.value('(action[@name="client_app_name"]/value)[1]','varchar(255)') NOT LIKE '%' + ISNULL(@client_app_NOT_LIKE,'') + '%'
				AND n.value('(@timestamp)[1]','datetime') + GETDATE() - GETUTCDATE() BETWEEN @beginDateTime AND @endDateTime
		END
		ELSE
		BEGIN
			INSERT INTO #GT25_EVENTS(event_name,[timestamp],cpu_time,duration,physical_reads,logical_reads,writes,result,row_count,
										connection_reset_option,connection_reset_option_text,[object_name],[statement],data_stream,output_parameters,
										client_app_name,client_hostname,is_system,nt_username,plan_handle,session_id,database_name)
			SELECT n.value('(@name)[1]','varchar(50)') AS event_name,
					n.value('(@timestamp)[1]','datetime') + GETDATE() - GETUTCDATE() AS timestamp,
					CONVERT(decimal(10,2),n.value('(data[@name="cpu_time"]/value)[1]','float')/1000000.0) AS cpu_time,
					CONVERT(decimal(10,2),n.value('(data[@name="duration"]/value)[1]','float')/1000000.0) AS duration,
					n.value('(data[@name="physical_reads"]/value)[1]','bigint') AS physical_reads,
					n.value('(data[@name="logical_reads"]/value)[1]','bigint') AS logical_reads,
					n.value('(data[@name="writes"]/value)[1]','bigint') AS writes,
					n.value('(data[@name="result"]/value)[1]','bigint') AS result,
					n.value('(data[@name="row_count"]/value)[1]','bigint') AS row_count,
					n.value('(data[@name="connection_reset_option"]/value)[1]','bigint') AS connection_reset_option,
					n.value('(data[@name="connection_reset_option"]/text)[1]','varchar(255)') AS connection_reset_option_text,
					n.value('(data[@name="object_name"]/value)[1]','varchar(255)') AS object_name,
					n.value('(data[@name="statement"]/value)[1]','varchar(MAX)') AS statement,
					n.value('(data[@name="data_stream"]/value)[1]','varchar(MAX)') AS data_stream,
					n.value('(data[@name="output_parameters"]/value)[1]','varchar(MAX)') AS output_parameters,
					n.value('(action[@name="client_app_name"]/value)[1]','varchar(255)') AS client_app_name,
					n.value('(action[@name="client_hostname"]/value)[1]','varchar(255)') AS client_hostname,
					n.value('(action[@name="is_system"]/value)[1]','varchar(20)') AS is_system,
					n.value('(action[@name="nt_username"]/value)[1]','varchar(255)') AS nt_username,
					n.value('(action[@name="plan_handle"]/value)[1]','varchar(255)') AS plan_handle,
					n.value('(action[@name="session_id"]/value)[1]','int') AS session_id,
					n.value('(action[@name="database_name"]/value)[1]','varchar(255)') AS database_name
			FROM (SELECT CAST(event_data AS XML) event_data
				  FROM sys.fn_xe_file_target_read_file(@filePath,NULL,NULL,NULL)) AS tab
				CROSS APPLY [event_data].[nodes]('event') AS [q] ([n])
			WHERE LEN(ISNULL(@client_app_NOT_LIKE,'')) = 0 OR n.value('(action[@name="client_app_name"]/value)[1]','varchar(255)') NOT LIKE '%' + ISNULL(@client_app_NOT_LIKE,'') + '%'
	
			SELECT * 
			FROM #GT25_EVENTS
			WHERE [timestamp] BETWEEN @beginDateTime AND @endDateTime
			ORDER BY [timestamp]
		END
	END
	------------------------------------------------------
	ELSE IF @eventName = 'Errors'
	-- ERRORS --------------------------------------------
	BEGIN
		IF OBJECT_ID('tempdb..#ERROR_EVENTS') IS NOT NULL
			DROP TABLE #ERROR_EVENTS;
		CREATE TABLE #ERROR_EVENTS
		(
			[timestamp] datetime,
			[error_number] int,
			severity  int,
			[state] int,
			[message] varchar(MAX),
			database_name varchar(255),
			client_app_name varchar(255),
			client_hostname varchar(255),
			nt_username varchar(255),
			session_id int,
			user_defined varchar(20),
			category int,
			category_text varchar(255),
			destination varchar(255),
			destination_text varchar(255),
			is_system varchar(20),
			plan_handle varchar(255),
			[sql_handle] varchar(255),
			event_name varchar(50)
		)

		IF @xmlOnly = 1
		BEGIN
			SELECT event_data
			FROM (SELECT CAST(event_data AS XML) event_data
				  FROM sys.fn_xe_file_target_read_file(@filePath,NULL,NULL,NULL)) AS tab
				CROSS APPLY [event_data].[nodes]('event') AS [q] ([n])
			WHERE LEN(ISNULL(@client_app_NOT_LIKE,'')) = 0 OR n.value('(action[@name="client_app_name"]/value)[1]','varchar(255)') NOT LIKE '%' + ISNULL(@client_app_NOT_LIKE,'') + '%'
		END
		ELSE
		BEGIN
			INSERT INTO #ERROR_EVENTS(event_name,[timestamp],database_name,[error_number],severity,[state],user_defined,category,category_text,
										destination,destination_text,[message],client_app_name,client_hostname,is_system,nt_username,plan_handle,session_id,[sql_handle])
			SELECT n.value('(@name)[1]','varchar(50)') AS event_name,
					n.value('(@timestamp)[1]','datetime') + GETDATE() - GETUTCDATE() AS timestamp,
					n.value('(action[@name="database_name"]/value)[1]','varchar(255)') AS database_name,
					n.value('(data[@name="error_number"]/value)[1]','int') AS error_number,
					n.value('(data[@name="severity"]/value)[1]','int') AS severity,
					n.value('(data[@name="state"]/value)[1]','int') AS state,
					n.value('(data[@name="user_defined"]/value)[1]','varchar(20)') AS user_defined,
					n.value('(data[@name="category"]/value)[1]','int') AS category,
					n.value('(data[@name="category"]/text)[1]','varchar(255)') AS category_text,
					n.value('(data[@name="destination"]/value)[1]','varchar(255)') AS destination,
					n.value('(data[@name="destination"]/text)[1]','varchar(255)') AS destination_text,
					n.value('(data[@name="message"]/value)[1]','varchar(MAX)') AS message,
					n.value('(action[@name="client_app_name"]/value)[1]','varchar(255)') AS client_app_name,
					n.value('(action[@name="client_hostname"]/value)[1]','varchar(255)') AS client_hostname,
					n.value('(action[@name="is_system"]/value)[1]','varchar(20)') AS is_system,
					n.value('(action[@name="nt_username"]/value)[1]','varchar(255)') AS nt_username,
					n.value('(action[@name="plan_handle"]/value)[1]','varchar(255)') AS plan_handle,
					n.value('(action[@name="session_id"]/value)[1]','int') AS session_id,
					n.value('(action[@name="tsql_stack"]/value/frames/frame[@level="1"][@handle])[1]','varchar(255)') AS sql_handle
			FROM (SELECT CAST(event_data AS XML) event_data
				  FROM sys.fn_xe_file_target_read_file(@filePath,NULL,NULL,NULL)) AS tab
				CROSS APPLY [event_data].[nodes]('event') AS [q] ([n])
			WHERE LEN(ISNULL(@client_app_NOT_LIKE,'')) = 0 OR n.value('(action[@name="client_app_name"]/value)[1]','varchar(255)') NOT LIKE '%' + ISNULL(@client_app_NOT_LIKE,'') + '%'

			SELECT * 
			FROM #ERROR_EVENTS
			WHERE [timestamp] BETWEEN @beginDateTime AND @endDateTime
				AND (LEN(ISNULL(@errorNumberIN,'')) = 0 OR [error_number] IN(SELECT value FROM string_split(@errorNumberIN,',')))
				AND (LEN(ISNULL(@errorNumberNOT_IN,'')) = 0 OR [error_number] NOT IN(SELECT value FROM string_split(@errorNumberNOT_IN,',')))
				AND [message] LIKE '%' + @errorMessageLIKE + '%'
			ORDER BY [timestamp]
		END
	END
	------------------------------------------------------
	ELSE IF @eventName = 'TimeOuts'
	-- TIME OUTS -----------------------------------------
	BEGIN
		IF OBJECT_ID('tempdb..#TO_EVENTS') IS NOT NULL
			DROP TABLE #TO_EVENTS;
		CREATE TABLE #TO_EVENTS
		(
			[timestamp] datetime,
			client_app_name varchar(255),
			database_name varchar(255),
			[statement] varchar(MAX),
			[object_name] varchar(255),
			output_parameters varchar(MAX),
			duration decimal(10,2),
			cpu_time decimal(10,2),
			physical_reads bigint,
			logical_reads bigint,
			writes bigint,
			row_count bigint,
			client_hostname varchar(255),
			nt_username varchar(255),
			session_id int,
			plan_handle varchar(255),
			connection_reset_option bigint,
			connection_reset_option_text varchar(255),
			data_stream varchar(MAX),
			is_system varchar(20),
			result bigint,
			event_name varchar(50)
		)

		IF @xmlOnly = 1
		BEGIN
			SELECT event_data
			FROM (SELECT CAST(event_data AS XML) event_data
				  FROM sys.fn_xe_file_target_read_file(@filePath,NULL,NULL,NULL)) AS tab
				CROSS APPLY [event_data].[nodes]('event') AS [q] ([n])
			WHERE LEN(ISNULL(@client_app_NOT_LIKE,'')) = 0 OR n.value('(action[@name="client_app_name"]/value)[1]','varchar(255)') NOT LIKE '%' + ISNULL(@client_app_NOT_LIKE,'') + '%'
		END
		ELSE
		BEGIN
			INSERT INTO #TO_EVENTS(event_name,[timestamp],cpu_time,duration,physical_reads,logical_reads,writes,result,row_count,
										connection_reset_option,connection_reset_option_text,[object_name],[statement],data_stream,output_parameters,
										client_app_name,client_hostname,is_system,nt_username,plan_handle,session_id,database_name)
			SELECT n.value('(@name)[1]','varchar(50)') AS event_name,
					n.value('(@timestamp)[1]','datetime') + GETDATE() - GETUTCDATE() AS timestamp,
					CONVERT(decimal(10,2),n.value('(data[@name="cpu_time"]/value)[1]','float')/1000000.0) AS cpu_time,
					CONVERT(decimal(10,2),n.value('(data[@name="duration"]/value)[1]','float')/1000000.0) AS duration,
					n.value('(data[@name="physical_reads"]/value)[1]','bigint') AS physical_reads,
					n.value('(data[@name="logical_reads"]/value)[1]','bigint') AS logical_reads,
					n.value('(data[@name="writes"]/value)[1]','bigint') AS writes,
					n.value('(data[@name="result"]/value)[1]','bigint') AS result,
					n.value('(data[@name="row_count"]/value)[1]','bigint') AS row_count,
					n.value('(data[@name="connection_reset_option"]/value)[1]','bigint') AS connection_reset_option,
					n.value('(data[@name="connection_reset_option"]/text)[1]','varchar(255)') AS connection_reset_option_text,
					n.value('(data[@name="object_name"]/value)[1]','varchar(255)') AS object_name,
					n.value('(data[@name="statement"]/value)[1]','varchar(MAX)') AS statement,
					n.value('(data[@name="data_stream"]/value)[1]','varchar(MAX)') AS data_stream,
					n.value('(data[@name="output_parameters"]/value)[1]','varchar(MAX)') AS output_parameters,
					n.value('(action[@name="client_app_name"]/value)[1]','varchar(255)') AS client_app_name,
					n.value('(action[@name="client_hostname"]/value)[1]','varchar(255)') AS client_hostname,
					n.value('(action[@name="is_system"]/value)[1]','varchar(20)') AS is_system,
					n.value('(action[@name="nt_username"]/value)[1]','varchar(255)') AS nt_username,
					n.value('(action[@name="plan_handle"]/value)[1]','varchar(255)') AS plan_handle,
					n.value('(action[@name="session_id"]/value)[1]','int') AS session_id,
					n.value('(action[@name="database_name"]/value)[1]','varchar(255)') AS database_name
			FROM (SELECT CAST(event_data AS XML) event_data
				  FROM sys.fn_xe_file_target_read_file(@filePath,NULL,NULL,NULL)) AS tab
				CROSS APPLY [event_data].[nodes]('event') AS [q] ([n])
			WHERE (LEN(ISNULL(@client_app_NOT_LIKE,'')) = 0 OR n.value('(action[@name="client_app_name"]/value)[1]','varchar(255)') NOT LIKE '%' + ISNULL(@client_app_NOT_LIKE,'') + '%')
				AND n.value('(@timestamp)[1]','datetime') + GETDATE() - GETUTCDATE() BETWEEN @beginDateTime AND @endDateTime

			SELECT * 
			FROM #TO_EVENTS
			WHERE [timestamp] BETWEEN @beginDateTime AND @endDateTime
			ORDER BY [timestamp]
		END
	END
END
GO