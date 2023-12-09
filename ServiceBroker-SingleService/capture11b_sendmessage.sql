-- Switch to the DBA database
USE DBA;
GO

-- Begin a conversation and send a request message
DECLARE @conversation_handle UNIQUEIDENTIFIER;
DECLARE @message_body XML;

BEGIN TRANSACTION;

BEGIN DIALOG @conversation_handle
     FROM SERVICE [HelloWorldService]
     TO SERVICE   N'HelloWorldService'
     ON CONTRACT  [HelloWorldContract]
     WITH ENCRYPTION = OFF;

SELECT @message_body = N'<HelloWorldMessage>Hello World!</HelloWorldMessage>';

SEND ON CONVERSATION @conversation_handle
     MESSAGE TYPE [HelloWorldMessage]
     (@message_body);

SELECT @message_body AS HelloWorldMessage;

COMMIT TRANSACTION;
GO

-- View the conversation we created
SELECT *
FROM sys.conversation_groups;
GO

-- View the message in the targets queue
SELECT *, 
	CAST(message_body AS XML) AS message_body_xml
FROM HelloWorldQueue;
GO

