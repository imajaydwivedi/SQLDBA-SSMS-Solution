USE DBA;
GO

IF OBJECT_ID('DBA..usp_SendWhoIsActiveMessage') IS NULL
	EXEC ('CREATE PROCEDURE dbo.usp_SendWhoIsActiveMessage AS SELECT 1 as Dummy;');
GO

ALTER PROCEDURE dbo.usp_SendWhoIsActiveMessage (@p_JobName varchar(225), @p_verbose bit = 0)
AS
BEGIN
	/*
		Created By:		Ajay Dwivedi
		Version:		0.0
		Modifications:	(26-Apr-2019) Creating Proc for 1st time
	*/

	-- Begin a conversation and send a request message
	DECLARE @conversation_handle UNIQUEIDENTIFIER;
	DECLARE @message_body XML;

	BEGIN TRANSACTION;

	BEGIN DIALOG @conversation_handle
		 FROM SERVICE [WhoIsActiveService]
		 TO SERVICE   N'WhoIsActiveService'
		 ON CONTRACT  [WhoIsActiveContract]
		 WITH ENCRYPTION = OFF;

	SELECT @message_body = N'<WhoIsActiveMessage>'+@p_JobName+'</WhoIsActiveMessage>';

	SEND ON CONVERSATION @conversation_handle
		 MESSAGE TYPE [WhoIsActiveMessage]
		 (@message_body);

	IF @p_verbose = 1
		PRINT '@message_body = '''+CAST(@message_body AS VARCHAR(255))+'''';

	COMMIT TRANSACTION;
END
GO