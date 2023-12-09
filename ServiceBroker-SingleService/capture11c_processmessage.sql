-- Switch to the HelloWorld_SSB database
USE DBA;
GO

-- Receive the request and send a reply
DECLARE @conversation_handle UNIQUEIDENTIFIER;
DECLARE @message_body XML;
DECLARE @message_type_name sysname;

BEGIN TRANSACTION;

WAITFOR
( RECEIVE TOP(1)
    @conversation_handle = conversation_handle,
    @message_body = message_body,
    @message_type_name = message_type_name
  FROM HelloWorldQueue
), TIMEOUT 1000;

IF (@message_type_name = N'HelloWorldMessage')
BEGIN
	-- Do processing and end the conversation if appropriate
	SELECT @message_body AS ReceivedRequestMsg;
	END CONVERSATION @conversation_handle;
END

-- Remember to cleanup dialogs by handling EndDialog messages 
ELSE IF (@message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
BEGIN
	 SELECT 'Handling EndDialog message';
     END CONVERSATION @conversation_handle;
END

COMMIT TRANSACTION;
GO

-- Check for the message in the targets queue
SELECT *, 
	CAST(message_body AS XML) AS message_body_xml
FROM HelloWorldQueue;
GO

