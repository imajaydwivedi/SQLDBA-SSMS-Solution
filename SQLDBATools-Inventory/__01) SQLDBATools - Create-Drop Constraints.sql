USE SQLDBATools;  
GO  
ALTER TABLE [dbo].[Server] DROP CONSTRAINT FK_dbo_Server_ApplicationId;   
GO 
ALTER TABLE [dbo].[Server] ADD CONSTRAINT FK_dbo_Server_ApplicationId FOREIGN KEY (ApplicationId) REFERENCES dbo.Application(ApplicationId)
GO

ALTER TABLE [dbo].[Instance] DROP CONSTRAINT FK_dbo_Instance_ServerId;   
GO 
ALTER TABLE [dbo].[Instance] ADD CONSTRAINT FK_dbo_Instance_ServerId FOREIGN KEY (ServerId) REFERENCES dbo.Server(ServerId)
GO
