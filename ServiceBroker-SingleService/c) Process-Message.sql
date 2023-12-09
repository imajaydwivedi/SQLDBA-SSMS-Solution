-- Switch to the HelloWorld_SSB database
--USE DBA;
--GO

USE DBA;
SET NOCOUNT ON;
-- Receive the request and send a reply
DECLARE @conversation_handle UNIQUEIDENTIFIER;
DECLARE @message_body XML;
DECLARE @message_type_name sysname;
DECLARE @isExecutedOnce bit = 0;
DECLARE @jobName varchar(255);

WHILE EXISTS (SELECT * FROM WhoIsActiveQueue)
BEGIN
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
		-- Do processing and end the conversation if appropriate
		--SELECT @message_body AS ReceivedRequestMsg;
		/*
		CREATE TABLE DBA..WhoIsActiveCallerDetails
			(JobName varchar(255) not null, collection_time smalldatetime default getdate())
		*/
		SET @jobName = CAST(@message_body AS XML).value('(/WhoIsActiveMessage)[1]', 'varchar(125)' );

		INSERT DBA..WhoIsActiveCallerDetails (JobName)
		SELECT @jobName AS JobName;

		--	DBA.dbo.fn_IsJobRunning()

		IF @isExecutedOnce = 0 OR DBA.dbo.fn_IsJobRunning(@jobName) = 1
		BEGIN
			DECLARE	@destination_table VARCHAR(4000);
			SET @destination_table = 'DBA.dbo.WhoIsActive_ResultSets';

			EXEC DBA..sp_WhoIsActive @get_full_inner_text=0, @get_transaction_info=1, @get_task_info=2, @get_locks=1, 
								@get_avg_time=1, @get_additional_info=1,@find_block_leaders=1, @get_outer_command =1,
								@get_plans=2,
						@destination_table = @destination_table ;
			SET @isExecutedOnce = 1;
		END

		END CONVERSATION @conversation_handle;
	END

	-- Remember to cleanup dialogs by handling EndDialog messages 
	ELSE IF (@message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
	BEGIN
		 --SELECT 'Handling EndDialog message';
		 END CONVERSATION @conversation_handle;
	END

	COMMIT TRANSACTION;
END


/*
-- Check for the message in the targets queue
SELECT *, 
	CAST(message_body AS XML) AS message_body_xml
FROM WhoIsActiveQueue;

SELECT * FROM sys.service_queues

ALTER QUEUE WhoIsActiveQueue WITH STATUS = ON
GO
*/

/*
Msg 9617, Level 16, State 1, Line 17
The service queue "WhoIsActiveQueue" is currently disabled.
*/