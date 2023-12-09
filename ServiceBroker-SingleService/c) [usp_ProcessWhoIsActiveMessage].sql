USE DBA;
GO

IF OBJECT_ID('DBA..usp_ProcessWhoIsActiveMessage') IS NULL
	EXEC ('CREATE PROCEDURE dbo.usp_ProcessWhoIsActiveMessage AS SELECT 1 as Dummy;');
GO

ALTER PROCEDURE dbo.usp_ProcessWhoIsActiveMessage (@p_verbose bit = 0)
AS
BEGIN -- Procedure body
	/*
		Created By:		Ajay Dwivedi
		Version:		0.0
		Modification:	(26-Apr-2019) Creating Proc for 1st time
	*/
	SET NOCOUNT ON;
	
	-- Receive the request and send a reply
	DECLARE @conversation_handle UNIQUEIDENTIFIER;
	DECLARE @message_body XML;
	DECLARE @message_type_name sysname;
	DECLARE @isExecutedOnce bit = 0;
	DECLARE @jobName varchar(255);
	DECLARE @_ErrorMessage varchar(max);
	DECLARE @l_counter INT = 1;
	DECLARE @l_counter_max INT;

	IF EXISTS (SELECT * FROM sys.service_queues WHERE name = 'WhoIsActiveQueue' AND (is_receive_enabled = 0 OR is_enqueue_enabled = 0))
		ALTER QUEUE WhoIsActiveQueue WITH STATUS = ON;

	SELECT @l_counter_max = COUNT(*) FROM WhoIsActiveQueue;

	WHILE @l_counter <= @l_counter_max
	BEGIN -- Loop Body
		BEGIN TRANSACTION;
		--WAITFOR ( 
			RECEIVE TOP(1)
			@conversation_handle = conversation_handle,
			@message_body = message_body,
			@message_type_name = message_type_name
		  FROM WhoIsActiveQueue
		--), TIMEOUT 1000;

		IF (@message_type_name = N'WhoIsActiveMessage')
		BEGIN
			SET @jobName = CAST(@message_body AS XML).value('(/WhoIsActiveMessage)[1]', 'varchar(125)' );

			INSERT DBA..WhoIsActiveCallerDetails (JobName)
			SELECT @jobName AS JobName;

			IF @isExecutedOnce = 0 OR DBA.dbo.fn_IsJobRunning(@jobName) = 1
			BEGIN
				
				IF DBA.dbo.fn_IsJobRunning('DBA - Log_With_sp_WhoIsActive') = 0
					EXEC msdb..sp_start_job @job_name = 'DBA - Log_With_sp_WhoIsActive';
				ELSE
					PRINT 'Job ''DBA - Log_With_sp_WhoIsActive'' is already running.';
					SET @isExecutedOnce = 1;
			END

			END CONVERSATION @conversation_handle;
		END

		-- Remember to cleanup dialogs by handling EndDialog messages 
		ELSE IF (@message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
		BEGIN
			 END CONVERSATION @conversation_handle;
		END

		COMMIT TRANSACTION;

		WAITFOR DELAY '00:00:05';
		SET @l_counter = @l_counter + 1;
	END -- Loop Body
END -- Procedure body
GO