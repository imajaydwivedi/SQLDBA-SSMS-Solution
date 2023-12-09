-- Switch to the DBA database
USE DBA;
GO

-- Begin a conversation and send a request message
DECLARE @conversation_handle UNIQUEIDENTIFIER;
DECLARE @message_body XML;

BEGIN TRANSACTION;

BEGIN DIALOG @conversation_handle
     FROM SERVICE [WhoIsActiveService]
     TO SERVICE   N'WhoIsActiveService'
     ON CONTRACT  [WhoIsActiveContract]
     WITH ENCRYPTION = OFF;

SELECT @message_body = N'<WhoIsActiveMessage>'+CAST(GETDATE() AS VARCHAR(30))+'</WhoIsActiveMessage>';

SEND ON CONVERSATION @conversation_handle
     MESSAGE TYPE [WhoIsActiveMessage]
     (@message_body);

SELECT @message_body AS WhoIsActiveMessage;

COMMIT TRANSACTION;
GO

-- View the conversation we created
SELECT *
FROM sys.conversation_groups;
GO

-- View the message in the targets queue
SELECT CAST(message_body AS XML) AS message_body_xml
		,CAST(message_body AS XML).value('(/WhoIsActiveMessage)[1]', 'varchar(125)' ) 
		,*
FROM WhoIsActiveQueue;
GO

