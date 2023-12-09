USE SQLDBATools
GO
--	DROP TABLE [Staging].[CollectionErrors]
CREATE TABLE [Staging].[CollectionErrors]
(	ServerName [varchar](125) NULL,
	Cmdlet [varchar](50) NOT NULL,
	Command [varchar](500) NULL,
	Error [varchar](max) NULL,
	Remark [varchar](max) NULL,
	CollectionTime [datetime]  DEFAULT getdate()
) ON [StagingData]
GO

-- DROP TABLE [dbo].[Application]
CREATE TABLE [dbo].[Application]
(
	[ApplicationID] [INT] IDENTITY(1,1) NOT NULL,
	[Category] [varchar](125) NOT NULL,
	[BusinessUnit] [varchar](125) NOT NULL,
	[ApplicationName] [varchar](125) NULL,
	[Priority] [tinyint] NULL,
	[BusinessOwner] [varchar](125) NULL,	
	[TechnicalOwner] [varchar](125) NULL,	
	[SecondaryTechnicalOwner] [varchar](125) NULL,
	[Remark1] [varchar](255) NULL,
	[Remark2] [varchar](255) NULL,
	[CollectionDate] DATETIME2 NULL DEFAULT GETDATE(),
	[CollectedBy] [varchar](50) NULL,
	[UpdatedDate] DATETIME2 NULL DEFAULT GETDATE(),
	[UpdatedBy] [varchar](50) NULL
	
	,CONSTRAINT PK_dbo_Application PRIMARY KEY CLUSTERED ([ApplicationID]) ON [MasterData]
) ON [MasterData]
GO

CREATE UNIQUE INDEX UK_dbo_Application_ApplicationName_BusinessUnit_Product ON dbo.[Application] ([Category],[BusinessUnit],[ApplicationName], [BusinessOwner], [TechnicalOwner], [SecondaryTechnicalOwner]); 
GO

ALTER TABLE [dbo].[Application] ADD CONSTRAINT CHK_Application_EnsureContactDetails CHECK ([BusinessOwner] IS NOT NULL OR [TechnicalOwner] IS NOT NULL OR [SecondaryTechnicalOwner] IS NOT NULL);  
GO  

USE SQLDBATools;
-- DROP TABLE [Staging].[ServerInfo]
CREATE TABLE [Staging].[ServerInfo]
(
	[ServerName] [varchar](50) NOT NULL,
	[ApplicationId] [INT] NULL,
	[EnvironmentType] [CHAR](4) NULL,
	[FQDN] [varchar](125) NOT NULL,
	[IPAddress] [varchar](15) NULL,
	[Domain] [nvarchar](30) NULL DEFAULT 'Contso',
	[IsStandaloneServer] [BIT] NULL DEFAULT 1,
	[IsSqlClusterNode] [BIT]  NULL DEFAULT 0,
	[IsAgNode] [BIT]  NULL DEFAULT 0,
	[IsWSFC] [BIT]  NULL DEFAULT 0,
	[IsSqlCluster] [BIT]  NULL DEFAULT 0,
	[IsAG] [BIT]  NULL DEFAULT 0,
	[ParentServerName] [varchar](50) NULL,
	[OS] [varchar](125)  NULL,
	[SPVersion] [varchar](50) NULL,
	[IsVM] [BIT]  NULL DEFAULT 1,
	[IsPhysical] [BIT]  NULL DEFAULT 0,
	[Manufacturer] [varchar](125) NULL,
	[Model] [varchar](125) NULL,
	[RAM] int  NULL,
	[CPU] [SMALLINT]  NULL,
	[Powerplan] [varchar](50) NULL,
	[OSArchitecture] [char](6) NULL,
	[ISDecom] [BIT]  NULL DEFAULT 0,
	[DecomDate] DATETIME2 NULL,
	[GeneralDescription] varchar(max) NULL,
	[CollectionDate] DATETIME2  NULL DEFAULT GETDATE(),
	[CollectedBy] [varchar](50)  NULL,
	[UpdatedDate] DATETIME2  NULL DEFAULT GETDATE(),
	[UpdatedBy] [varchar](50)  NULL
) ON [StagingData]
GO

--SELECT COLUMN_NAME FROM Information_schema.columns c where c.table_name = 'ServerInfo'

--	drop table [dbo].[server]
CREATE TABLE [dbo].[Server]
(
	[ServerID] [INT] IDENTITY(1,1) NOT NULL,
	[ServerName] varchar(50) NOT NULL, --AS LEFT([FQDN],CHARINDEX('.',[FQDN])-1) PERSISTED,
	[ApplicationId] [INT] NULL,
	[EnvironmentType] [CHAR](4) NULL,
	[FQDN] [varchar](125) NOT NULL,
	[IPAddress] [varchar](15) NULL,
	[Domain] [nvarchar](30) NULL DEFAULT 'Contso',
	[IsStandaloneServer] [BIT] NULL DEFAULT 1,
	[IsSqlClusterNode] [BIT] NULL DEFAULT 0,
	[IsAgNode] [BIT] NULL DEFAULT 0,
	[IsWSFC] [BIT] NULL DEFAULT 0,
	[IsSqlCluster] [BIT] NULL DEFAULT 0,
	[IsAG] [BIT] NULL DEFAULT 0,
	[ParentServerId] [INT] NULL,
	[OS] [varchar](125) NULL,
	[SPVersion] [varchar](50) NULL,
	[IsVM] [BIT] NULL DEFAULT 1,
	[IsPhysical] [BIT] NULL DEFAULT 0,
	[Manufacturer] [varchar](125) NULL,
	[Model] [varchar](125) NULL,
	[RAM] int NULL,
	[CPU] [SMALLINT] NULL,
	[Powerplan] [varchar](50) NULL,
	[OSArchitecture] [char](6) NULL,
	[ISDecom] [BIT] NULL DEFAULT 0,
	[DecomDate] DATETIME2 NULL,
	[GeneralDescription] varchar(max) NULL,
	[Remark1] varchar(255) NULL,
	[Remark2] varchar(255) NULL,
	[CollectionDate] DATETIME2 NULL DEFAULT GETDATE(),
	[CollectedBy] [varchar](50) NULL,
	[UpdatedDate] DATETIME2 NULL DEFAULT GETDATE(),
	[UpdatedBy] [varchar](50) NULL

	,CONSTRAINT PK_dbo_Server PRIMARY KEY CLUSTERED (ServerID) ON [MasterData]
	,CONSTRAINT UK_dbo_Server_ServerName UNIQUE NONCLUSTERED ([ServerName]) ON [MasterData]
	,CONSTRAINT UK_dbo_Server_FQDN UNIQUE NONCLUSTERED ([FQDN]) ON [MasterData]
	,CONSTRAINT CHK_dbo_Server_ServerNameFQDN CHECK([ServerName] = LEFT([FQDN],CHARINDEX('.',[FQDN])-1))
	,CONSTRAINT FK_dbo_Server_ParentServerId FOREIGN KEY (ParentServerId) REFERENCES dbo.Server(ServerID)
	,CONSTRAINT FK_dbo_Server_ApplicationId FOREIGN KEY (ApplicationId) REFERENCES dbo.Application(ApplicationId)
) ON [MasterData]
GO

USE SQLDBATools;
--	drop table [Staging].[InstanceInfo]
--alter table [Staging].[InstanceInfo] alter column [Version] [varchar](15) null
CREATE TABLE [Staging].[InstanceInfo]
(
	[ServerName] [varchar] (125) NOT NULL,
	[SqlInstance] [varchar](125) NOT NULL,
	[InstanceName] [varchar](50) NOT NULL,
	[RootDirectory] [varchar](255) NULL,
	[Version] [varchar](15) NULL,
	[CommonVersion] [CHAR](5) NULL,
	[Build] int NULL,
	[VersionString] [varchar](125) NULL,
	[Edition] [varchar](50) NULL,
	[Collation] [varchar](50) NULL,
	[ProductKey] [char](29) NULL,
	[DefaultDataLocation] [varchar](255) NULL,
	[DefaultLogLocation] [varchar](255) NULL,
	[DefaultBackupLocation] [varchar](255) NULL,
	[ErrorLogPath] [varchar](255) NULL,
	[ServiceAccount] [varchar](125) NULL,
	[Port] [varchar](6) NULL,
	[IsStandaloneInstance] BIT NULL DEFAULT 1,
	[IsSQLCluster] BIT NULL DEFAULT 0,
	[IsAGListener] BIT  NULL DEFAULT 0,
	[IsAGNode] BIT  NULL DEFAULT 0,
	[AGListenerName] [varchar](125) NULL,
	[HasOtherHASetup] BIT  NULL DEFAULT 0,
	[HARole] [varchar](20) NULL,
	[HAPartner] [varchar](125) NULL,
	[IsPowershellLinked] BIT NULL DEFAULT 0,
	[IsDecom] BIT  NULL DEFAULT 0,
	[DecomDate] DATETIME2 NULL,
	[CollectionDate] DATETIME2  NULL DEFAULT GETDATE(),
	[CollectedBy] [varchar](50)  NULL,
	[UpdatedDate] DATETIME2 NULL DEFAULT GETDATE(),
	[UpdatedBy] [varchar](50) NULL,
	[Remark1] varchar(max) NULL,
	[Remark2] varchar(max) NULL
) ON [StagingData]
GO

--	drop table dbo.Instance
USE SQLDBATools
GO
CREATE TABLE [dbo].[Instance]
(
	[InstanceID] [int] IDENTITY(1,1) NOT NULL,
	[ServerID] [int] NOT NULL,
	[SqlInstance] [varchar](125) NOT NULL,
	[InstanceName] [varchar](50) NOT NULL,
	[RootDirectory] [varchar](255) NULL,
	[Version] [varchar](15) NULL,
	[CommonVersion] [CHAR](5) NULL,
	[Build] int NULL,
	[VersionString] [varchar](125) NULL,
	[Edition] [varchar](50) NULL,
	[Collation] [varchar](50) NULL,
	[ProductKey] [char](29) NULL,
	[DefaultDataLocation] [varchar](255) NULL,
	[DefaultLogLocation] [varchar](255) NULL,
	[DefaultBackupLocation] [varchar](255) NULL,
	[ErrorLogPath] [varchar](255) NULL,
	[ServiceAccount] [varchar](125) NULL,
	[Port] [varchar](6) NULL,
	[IsStandaloneInstance] BIT NULL DEFAULT 1,
	[IsSQLCluster] BIT NULL DEFAULT 0,
	[IsAGListener] BIT NULL DEFAULT 0,
	[IsAGNode] BIT NULL DEFAULT 0,
	[AGListener] int NULL,
	[HasOtherHASetup] BIT NULL DEFAULT 0,
	[HARole] [varchar](20) NULL,
	[HAPartner] int NULL,
	[IsPowershellLinked] BIT NULL DEFAULT 0,
	[IsDecom] BIT NULL DEFAULT 0,
	[DecomDate] DATETIME2 NULL,
	[CollectionDate] DATETIME2 NULL DEFAULT GETDATE(),
	[CollectedBy] [varchar](50) NULL,
	[UpdatedDate] DATETIME2 NULL DEFAULT GETDATE(),
	[UpdatedBy] [varchar](50) NULL,
	[Remark1] varchar(max) NULL,
	[Remark2] varchar(max) NULL
	
	,CONSTRAINT PK_dbo_Instance PRIMARY KEY CLUSTERED (InstanceID) ON [MasterData]
	,CONSTRAINT UK_dbo_Instance_SqlInstance UNIQUE NONCLUSTERED ([SqlInstance]) ON [MasterData]
	,CONSTRAINT FK_dbo_Instance_ServerId FOREIGN KEY (ServerId) REFERENCES dbo.Server(ServerID)
	--,CONSTRAINT CHK_dbo_Instance_Edition CHECK([Edition] IN ('ENTERPRISE','DEVELOPER','STANDARD','EXPRESS'))
	,CONSTRAINT FK_dbo_Instance_AGListener FOREIGN KEY (AGListener) REFERENCES dbo.Instance(InstanceID)
	--[HARole]
	,CONSTRAINT CHK_dbo_Instance_HARole CHECK(HARole IN ('MirrorPartner','MirrorPrincipal','MirrorWitness','ReplicationPublisher','ReplicationSubscriber','LogShippingSource','LogShippingDestination'))
	,CONSTRAINT FK_dbo_Instance_HAPartner FOREIGN KEY (HAPartner) REFERENCES dbo.Instance(InstanceID)
) ON [MasterData]
GO

/*
;with t_Anant as
(
	SELECT distinct a.Category, a.BusinessUnit, a.BusinessOwner, a.TechnicalOwner, a.SecondaryTechnicalOwner  FROM dbo.Server_Anant as a
)
select * from dbo.Application o
	where o

SELECT distinct a.Category, a.BusinessUnit, a.BusinessOwner, a.TechnicalOwner, a.SecondaryTechnicalOwner  FROM dbo.Server_Anant as a WHERE a.Server = 'YourDbServerName'

select a.*
from DbaTestServer.SQLDBATools.Info.Server s 
join DbaTestServer.SQLDBATools.Info.[Xref_ApplicationServer] x on x.ServerName = s.ServerName
join DbaTestServer.SQLDBATools.Info.[Application] as a on a.ApplicationID = x.ApplicationID
where s.ServerName  = 'YourDbServerName'

*/

