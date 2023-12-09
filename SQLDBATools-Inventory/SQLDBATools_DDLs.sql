USE [master]
GO
/****** Object:  Database [SQLDBATools]    Script Date: 4/10/2018 7:10:02 AM ******/
CREATE DATABASE [SQLDBATools] ON  PRIMARY 
( NAME = N'SQLDBATools', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\DATA\SQLDBATools.mdf' , SIZE = 2097152KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1048576KB ), 
 FILEGROUP [CollectedData] 
( NAME = N'SQLDBATools_CollectedData', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\DATA\SQLDBATools_CollectedData.ndf' , SIZE = 1048576KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1048576KB ), 
 FILEGROUP [MasterData] 
( NAME = N'SQLDBATools_MasterData', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\DATA\SQLDBATools_MasterData.ndf' , SIZE = 1048576KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1048576KB ), 
 FILEGROUP [StagingData] 
( NAME = N'SQLDBATools_StagingData', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\DATA\SQLDBATools_StagingData.ndf' , SIZE = 1048576KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1048576KB )
 LOG ON 
( NAME = N'SQLDBATools_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\DATA\SQLDBATools_log.ldf' , SIZE = 1048576KB , MAXSIZE = 2048GB , FILEGROWTH = 524288KB )
GO

USE [SQLDBATools]
GO

/****** Object:  Schema [info]    Script Date: 4/10/2018 7:12:26 AM ******/
CREATE SCHEMA [info]
GO

/****** Object:  Schema [Staging]    Script Date: 4/10/2018 7:12:26 AM ******/
CREATE SCHEMA [Staging]
GO

--	DROP TABLE [Staging].[CollectionErrors]
CREATE TABLE [Staging].[CollectionErrors]
(	ServerName [varchar](125) NULL,
	Cmdlet [varchar](50) NOT NULL,
	Command [varchar](500) NULL,
	Error [varchar](500) NULL,
	Remark [varchar](500) NULL,
	CollectionTime [datetime]  DEFAULT getdate()
) ON [StagingData]
GO
--USE SQLDBATools
--DROP TABLE [Staging].[ServerInfo]
CREATE TABLE [Staging].[ServerInfo]
(
	[ServerName] [varchar](125) NULL,
	[EnvironmentType] varchar(125) NOT NULL,
	[FQDN] [varchar](125) NULL, 
	[DNSHostName] [varchar](125) NULL,
	[IPAddress] [varchar](15) NULL,
	[Domain] [varchar](125) NULL,
	[OperatingSystem] [varchar](125) NULL,
	[SPVersion] [varchar](125) NULL,
	[OSArchitecture] [varchar](20) NULL,
	[IsVM] [int] NULL,
	[Manufacturer] [varchar](125) NULL,
	[Model] [varchar](125) NULL,
	[RAM] [int] NULL,
	[CPU] [tinyint] NULL,
	[PowerPlan] [varchar](50) NULL,
	[GeneralDescription] [varchar](500) NULL,
	[CollectionTime] [smalldatetime] NULL
) ON [StagingData]
GO

/*
	USE SQLDBATools;
	DROP TABLE [Staging].[DatabaseInfo]
*/
CREATE TABLE [Staging].[DatabaseInfo]
(
	[ComputerName] varchar (100) NULL,
	[InstanceName] varchar (100) NULL,
	[SqlInstance] varchar (100) NULL,
	[Name] varchar (100) NULL,
	[Owner] varchar (100) NULL,
	[RecoveryModel] varchar (20) NULL,
	[SizeMB] [float] NULL,
	[SpaceAvailable] [float] NULL,
	[Status] varchar (100) NULL,
	[UserAccess] varchar (100) NULL,
	[AutoClose] [bit] NULL,
	[AutoCreateStatisticsEnabled] [bit] NULL,
	[AutoShrink] [bit] NULL,
	[AutoUpdateStatisticsAsync] [bit] NULL,
	[AutoUpdateStatisticsEnabled] [bit] NULL,
	[CaseSensitive] [bit] NULL,
	[Collation] varchar (100) NULL,
	[CompatibilityLevel] varchar (100) NULL,
	[CreateDate] [datetime2](7) NULL,
	[DatabaseEngineEdition] varchar (100) NULL,
	[IsUpdateable] [bit] NULL
) ON [StagingData]
GO

--DROP TABLE [Info].[Server]
CREATE TABLE [Info].[Server]
(
	[ServerID] INT IDENTITY(1,1) NOT NULL,
	[ServerName] AS LEFT([FQDN],CHARINDEX('.',[FQDN])-1),
	[EnvironmentType] varchar(125) NOT NULL,
	[DNSHostName] [varchar](125) NULL,
	[FQDN] [varchar](125) NULL,
	[IPAddress] [varchar](15) NULL,
	[Domain] [varchar](125) NULL,
	[OperatingSystem] [varchar](125) NULL,
	[SPVersion] [varchar](125) NULL,
	[OSArchitecture] [varchar](20) NULL,
	[IsVM] BIT NULL,
	[Manufacturer] [varchar](125) NULL,
	[Model] [varchar](125) NULL,
	[RAM] [int] NULL,
	[CPU] [tinyint] NULL,
	[PowerPlan] [varchar](50) NULL,
	[GeneralDescription] [varchar](500) NULL,
	[CollectionTime] [smalldatetime] NULL,
	[UpdatedDate] [smalldatetime] NULL
) ON [MasterData]
GO

ALTER TABLE [Info].[Server]
	ADD CONSTRAINT pk_Info_Server PRIMARY KEY NONCLUSTERED (ServerID)
GO

--	ALTER TABLE [Info].[Server] DROP CONSTRAINT UK_Info_Server_ServerName
ALTER TABLE [Info].[Server] 
	ADD CONSTRAINT UK_Info_Server_FQDN UNIQUE NONCLUSTERED ([FQDN]) 
GO
--	============================================================================
--	============================================================================

--TRUNCATE TABLE [Staging].[DatabaseBackups]
--DROP TABLE [Staging].[InstanceInfo]
CREATE TABLE [Staging].[InstanceInfo]
(
	[FQDN] [varchar](125) NOT NULL,
	ServerName [varchar](125),
	InstanceName [varchar](125) NOT NULL,
	InstallDataDirectory [varchar](500),                   
	[Version] [varchar](50),
	Edition [varchar](50) NOT NULL,
	ProductKey [varchar](30),           
	IsClustered int,
	IsCaseSensitive int,
	IsHadrEnabled   int,
	IsDecommissioned int,
	IsPowerShellLinked  int,
	[CollectionTime] [datetime2](7) NOT NULL
) ON [StagingData]
GO

--	DROP TABLE [info].[Instance]
--	TRUNCATE TABLE [info].[Instance]
CREATE TABLE [Info].[Instance]
(
	[InstanceID] [int] IDENTITY(1,1) NOT NULL,
	[ServerID] [int] NOT NULL,
	[FQDN] [varchar](125),
	[ServerName] AS LEFT([FQDN],CHARINDEX('.',[FQDN])-1),
	InstanceName [varchar](125) NOT NULL,
	InstallDataDirectory [varchar](500) NULL,                   
	[Version] [varchar](50),
	[CommonVersion] AS LEFT([Version], CHARINDEX('.',[Version], CHARINDEX('.',[Version])+1 )-1),
	[VersionString] AS CASE WHEN [Version] LIKE '9.0%' THEN 'SQL Server 2005'
						WHEN [Version] LIKE '10.0%' THEN 'SQL Server 2008'
						WHEN [Version] LIKE '10.50%' THEN 'SQL Server 2008 R2'
						WHEN [Version] LIKE '11.0%' THEN 'SQL Server 2012'
						WHEN [Version] LIKE '12.0%' THEN 'SQL Server 2014'
						WHEN [Version] LIKE '13.0%' THEN 'SQL Server 2016'
						WHEN [Version] LIKE '14.0%' THEN 'SQL Server 2017'
						ELSE NULL
						END,
	[Build] AS SUBSTRING([Version],CHARINDEX('.',[Version], CHARINDEX('.',[Version])+1)+1,4),
	Edition [varchar](50) NOT NULL,
	ProductKey [varchar](30) NULL,           
	IsClustered [bit],
	IsCaseSensitive [bit],
	IsHadrEnabled   [bit],
	IsDecommissioned [bit],
	IsPowerShellLinked  [bit],
	[CollectionTime] [datetime2](7) NOT NULL
	PRIMARY KEY NONCLUSTERED 
	(
		[InstanceID] ASC
	) ON [MasterData]
) ON [MasterData]
GO

USE SQLDBATools;
--	drop table [Info].[Database]
CREATE TABLE [Info].[Database]
(
	[ComputerName] [varchar](100) NOT NULL,
	[InstanceName] [varchar](100) NOT NULL,
	[SqlInstance] [varchar](100) NOT NULL,
	[Name] [varchar](100) NOT NULL,
	[Owner] [varchar](100) NULL,
	[RecoveryModel] [varchar](20) NULL,
	[SizeMB] [float] NULL,
	[SpaceAvailable] [float] NULL,
	[Status] [varchar](100) NULL,
	[UserAccess] [varchar](100) NULL,
	[AutoClose] [bit] NULL,
	[AutoCreateStatisticsEnabled] [bit] NULL,
	[AutoShrink] [bit] NULL,
	[AutoUpdateStatisticsAsync] [bit] NULL,
	[AutoUpdateStatisticsEnabled] [bit] NULL,
	[CaseSensitive] [bit] NULL,
	[Collation] [varchar](100) NULL,
	[CompatibilityLevel] [varchar](100) NULL,
	[CreateDate] [datetime2](7) NULL,
	[DatabaseEngineEdition] [varchar](100) NULL,
	[IsUpdateable] [bit] NULL
	,CONSTRAINT PK_Database_SqlInstance_Name PRIMARY KEY CLUSTERED (SqlInstance,Name)
) ON [MasterData]
GO

ALTER TABLE [Info].[Instance] ALTER COLUMN InstallDataDirectory [varchar](500) NULL
GO
ALTER TABLE [Info].[Instance] ALTER COLUMN ProductKey [varchar](30) NULL
GO

ALTER TABLE [Info].[Instance] 
	ADD CONSTRAINT UK_Info_Instance_InstanceName UNIQUE CLUSTERED (InstanceName) 
GO

--	ALTER TABLE [info].[Instance] DROP CONSTRAINT FK__Info_Instance__ServerName
ALTER TABLE [info].[Instance]
	ADD CONSTRAINT FK__Info_Instance__ServerID FOREIGN KEY ([ServerID])     
    REFERENCES [Info].[Server]  ([ServerID]) 
GO

--	ALTER TABLE [info].[Instance] DROP CONSTRAINT FK__Info_Instance__ServerName
ALTER TABLE [info].[Instance]
	ADD CONSTRAINT FK__Info_Instance__FQDN FOREIGN KEY ([FQDN])     
    REFERENCES [Info].[Server]  ([FQDN]) 
GO
--	============================================================================
--	============================================================================
--	DROP TABLE [Staging].[ApplicationInfo]
CREATE TABLE [Staging].[ApplicationInfo]
(
	ApplicationName [varchar](125) NOT NULL,
	BusinessUnit [varchar](125) NOT NULL,
	Product [varchar](125) NOT NULL,
	[Priority] [INT] NULL,
	Owner_EmailId [varchar](125) NOT NULL,
	DelegatedOwner_EmailId [varchar](125) NULL,
	OwnershipDelegationEndDate [datetime] NULL,	
	PrimaryContact_EmailId [varchar](125) NOT NULL,	
	SecondaryContact_EmailId [varchar](125) NULL,
	SecondaryContact2_EmailId [varchar](125) NULL,
	CollectionTime [DATETIME] NULL
) ON [StagingData]
GO

--	DROP TABLE [Info].[Application]
CREATE TABLE [Info].[Application]
(
	[ApplicationID] [INT] IDENTITY(1,1) NOT NULL,
	ApplicationName [varchar](125) NOT NULL,
	BusinessUnit [varchar](125) NOT NULL,
	Product [varchar](125) NOT NULL,
	[Priority] [tinyint] NULL,
	Owner_EmailId [varchar](125) NOT NULL,
	DelegatedOwner_EmailId [varchar](125) NULL,
	OwnershipDelegationEndDate [datetime] NULL,	
	PrimaryContact_EmailId [varchar](125) NOT NULL,	
	SecondaryContact_EmailId [varchar](125) NULL,
	SecondaryContact2_EmailId [varchar](125) NULL,
	CollectionTime [DATETIME]
	PRIMARY KEY NONCLUSTERED 
	(
		[ApplicationID] ASC
	) ON [MasterData]
) ON [MasterData]
GO

ALTER TABLE [Info].[Application] 
	ADD CONSTRAINT UK_Info_Application_ApplicationName_BusinessUnit_Product UNIQUE CLUSTERED (ApplicationName, BusinessUnit, Product) 
GO

ALTER TABLE [Info].[Application]  WITH CHECK   
	ADD CONSTRAINT chk_Owner_EmailId CHECK (CHARINDEX('@',Owner_EmailId) > 0) ;  
GO
--	============================================================================
--	============================================================================
--DROP TABLE Info.Xref_ApplicationServer
CREATE TABLE Info.Xref_ApplicationServer
(
	FQDN VARCHAR (125) NOT NULL,
	[ServerName] AS LEFT([FQDN],CHARINDEX('.',[FQDN])-1),
	ApplicationID INT NOT NULL
	PRIMARY KEY CLUSTERED (FQDN, ApplicationID) ON [MasterData]
) ON [MasterData]
GO

ALTER TABLE [info].Xref_ApplicationServer
	ADD CONSTRAINT FK__Xref_ApplicationServer__FQDN FOREIGN KEY ([FQDN])     
    REFERENCES [Info].[Server]  ([FQDN]) 
GO
ALTER TABLE [info].Xref_ApplicationServer
	ADD CONSTRAINT FK__Xref_ApplicationServer__ApplicationID FOREIGN KEY (ApplicationID)     
    REFERENCES [Info].[Application]  (ApplicationID) 
GO

--	============================================================================
--	============================================================================
--DROP TABLE Info.Xref_ApplicationDatabase
CREATE TABLE Info.Xref_ApplicationDatabase
(
	InstanceName VARCHAR (125) NOT NULL,
	DatabaseName VARCHAR (125) NOT NULL,
	ApplicationID INT NOT NULL
	PRIMARY KEY CLUSTERED (InstanceName, ApplicationID) ON [MasterData]
) ON [MasterData]
GO
ALTER TABLE [info].Xref_ApplicationDatabase
	ADD CONSTRAINT FK__Xref_ApplicationDatabase__ApplicationID FOREIGN KEY (ApplicationID)     
    REFERENCES [Info].[Application]  (ApplicationID) 
GO
--	============================================================================
--	============================================================================

USE [SQLDBATools]
GO

CREATE TABLE [info].[Databases](
	[DatabaseID] [int] IDENTITY(1,1) NOT NULL,
	[InstanceID] [int] NOT NULL,
	[Name] [nvarchar](256) NULL,
	[DateAdded] [datetime2](7) NULL,
	[DateChecked] [datetime2](7) NULL,
	[AutoClose] [bit] NULL,
	[AutoCreateStatisticsEnabled] [bit] NULL,
	[AutoShrink] [bit] NULL,
	[AutoUpdateStatisticsEnabled] [bit] NULL,
	[AvailabilityDatabaseSynchronizationState] [nvarchar](16) NULL,
	[AvailabilityGroupName] [nvarchar](128) NULL,
	[CaseSensitive] [bit] NULL,
	[Collation] [nvarchar](40) NULL,
	[CompatibilityLevel] [nvarchar](15) NULL,
	[CreateDate] [datetime2](7) NULL,
	[DataSpaceUsageKB] [float] NULL,
	[EncryptionEnabled] [bit] NULL,
	[IndexSpaceUsageKB] [float] NULL,
	[IsAccessible] [bit] NULL,
	[IsFullTextEnabled] [bit] NULL,
	[IsMirroringEnabled] [bit] NULL,
	[IsParameterizationForced] [bit] NULL,
	[IsReadCommittedSnapshotOn] [bit] NULL,
	[IsSystemObject] [bit] NULL,
	[IsUpdateable] [bit] NULL,
	[LastBackupDate] [datetime2](7) NULL,
	[LastDifferentialBackupDate] [datetime2](7) NULL,
	[LastLogBackupDate] [datetime2](7) NULL,
	[Owner] [nvarchar](30) NULL,
	[PageVerify] [nvarchar](17) NULL,
	[ReadOnly] [bit] NULL,
	[RecoveryModel] [nvarchar](10) NULL,
	[ReplicationOptions] [nvarchar](40) NULL,
	[SizeMB] [float] NULL,
	[SnapshotIsolationState] [nvarchar](10) NULL,
	[SpaceAvailableKB] [float] NULL,
	[Status] [nvarchar](35) NULL,
	[TargetRecoveryTime] [int] NULL,
	[InActive] [bit] NULL,
	[LastRead] [datetime2](7) NULL,
	[LastWrite] [datetime2](7) NULL,
	[LastReboot] [datetime2](7) NULL,
	[LastDBCCDate] [datetime] NULL,
	 CONSTRAINT [PK_Databases] PRIMARY KEY CLUSTERED 
	(
		[DatabaseID] ASC
	) ON [MasterData]
)  ON [MasterData]
GO

--	============================================================================
--	============================================================================


--	DROP TABLE [info].[Volume]
--	TRUNCATE TABLE [info].[Volume]
CREATE TABLE [Info].[Volume]
(
	ID [BIGINT] IDENTITY(1,1) NOT NULL,
	[FQDN] [varchar](125) NOT NULL,
	[ServerName] AS LEFT([FQDN],CHARINDEX('.',[FQDN])-1),
	[VolumeName] [varchar](125) NOT NULL,
	[CapacityGB] [decimal](20, 2) NOT NULL,
	[UsedSpaceGB] [decimal](20, 2) NOT NULL,
	[UsedSpacePercent] [decimal](20, 2) NOT NULL,
	[FreeSpaceGB] [decimal](20, 2) NOT NULL,
	[Label] [varchar](125) NULL,
	[CollectionTime] [datetime2](7) NOT NULL
) ON [MasterData]
GO

ALTER TABLE [Info].[Volume] 
	ADD CONSTRAINT UK_Info_Volume_FQDN_VolumeName UNIQUE CLUSTERED ([FQDN], [VolumeName])
GO

ALTER TABLE [info].[Instance]
	ADD CONSTRAINT FK__Info_Instance__FQDN FOREIGN KEY ([FQDN])     
    REFERENCES [Info].[Server]  ([FQDN]) 
GO

CREATE TABLE [dbo].[VolumeInfo]
(
	ID [BIGINT] IDENTITY(1,1) NOT NULL,
	[ServerName] [varchar](125) NOT NULL,
	[VolumeName] [varchar](125) NOT NULL,
	[CapacityGB] [decimal](20, 2) NOT NULL,
	[UsedSpaceGB] [decimal](20, 2) NOT NULL,
	[UsedSpacePercent] [decimal](20, 2) NOT NULL,
	[FreeSpaceGB] [decimal](20, 2) NOT NULL,
	[Label] [varchar](125) NULL,
	[CollectionTime] [datetime2](7) NOT NULL
) ON [CollectedData]
GO

ALTER TABLE [dbo].[VolumeInfo]
	ADD CONSTRAINT pk_dbo_VolumeInfo PRIMARY KEY(ServerName,VolumeName)
GO

ALTER TABLE [dbo].[VolumeInfo]     
	ADD CONSTRAINT FK_VolumeInfo_ServerName FOREIGN KEY (ServerName)     
    REFERENCES [Info].[Server]  (ServerName)     
    --ON DELETE CASCADE    
    --ON UPDATE CASCADE  
GO

CREATE TABLE [Staging].[DatabaseBackups](
	[ServerName] [varchar](125),
	[DatabaseName] [varchar](125),
	[DatabaseCreationDate] [datetime2](7) NOT NULL,
	[RecoveryModel] [varchar](15) NOT NULL,
	[LastFullBackupDate] [datetime2](7) NULL,
	[LastDifferentialBackupDate] [datetime2](7) NULL,
	[LastLogBackupDate] [datetime2](7) NULL,
	[CollectionTime] [DATETIME2](7) NOT NULL
) ON [StagingData]
GO

CREATE TABLE Staging.VolumeInfo
(
	[ServerName] [varchar](125) NOT NULL,
	[VolumeName] [varchar](125),
	[CapacityGB] DECIMAL(20,2) NOT NULL,
	[UsedSpaceGB] DECIMAL(20,2) NOT NULL,
	[UsedSpacePercent] DECIMAL(20,2) NOT NULL,
	[FreeSpaceGB] DECIMAL(20,2) NOT NULL,
	[Label] [varchar](125) NULL,
	[CollectionTime] [datetime2](7) NOT NULL
) ON [StagingData]
GO

CREATE TABLE Staging.SecurityCheckInfo
(	
	ServerInstance varchar(125),
	principal_name varchar(125), 
	type_desc varchar(125), 
	role_permission varchar(125), 
	roleOrPermission varchar(125),
	CollectionTime datetime
) on [StagingData]
go

USE [SQLDBATools]
GO
--DROP TABLE  [dbo].[DatabaseBackup]
CREATE TABLE [dbo].[DatabaseBackup]
(
	[InstanceID] INT NOT NULL,
	[InstanceName] [varchar](125) NOT NULL,
	[DatabaseName] [sysname] NOT NULL,
	[DatabaseCreationDate] [smalldatetime] NOT NULL,
	[RecoveryModel] [varchar](15) NOT NULL,
	[LastFullBackupDate] [smalldatetime] NULL,
	[LastDifferentialBackupDate] [smalldatetime] NULL,
	[LastLogBackupDate] [smalldatetime] NULL,
	[CollectionTime] [smalldatetime] NOT NULL,
	[BatchNumber] [bigint] NOT NULL
) ON [CollectedData]
GO

ALTER TABLE [dbo].[DatabaseBackup]
	ADD CONSTRAINT pk_DatabaseBackup PRIMARY KEY([CollectionTime], [InstanceName], [DatabaseName])
GO

ALTER TABLE [dbo].[DatabaseBackup]     
ADD CONSTRAINT FK_DatabaseBackup_InstanceID FOREIGN KEY (InstanceID)     
    REFERENCES Info.[Instance] (InstanceID)     
    --ON DELETE CASCADE    
    --ON UPDATE CASCADE  
GO

CREATE TABLE dbo.JobHistory
(
	JobName SYSNAME NOT NULL,
	ScriptPath VARCHAR(255) NULL,
	StartTime smalldatetime NOT NULL
)
GO

CREATE table Info.PowerShellFunctionCalls
(
	ID BIGINT IDENTITY(1,1) NOT NULL,
	[CmdLetName] VARCHAR(125) NOT NULL,
	[ParentScript] VARCHAR(125) NULL,
	[ScriptText] VARCHAR(125) NOT NULL,
	[ServerName] VARCHAR(125) NULL,
	[Result] VARCHAR(50) DEFAULT 'Success',
	CollectionTime SMALLDATETIME DEFAULT GETDATE(),
	[ErrorMessage] VARCHAR(2000) NULL
) ON [StagingData]
GO
CREATE NONCLUSTERED INDEX NCI_Info_PowerShellFunctionCalls_CollectionTime ON Info.PowerShellFunctionCalls (CollectionTime)
ON [StagingData]
GO
CREATE NONCLUSTERED INDEX NCI_Info_PowerShellFunctionCalls_ServerName ON Info.PowerShellFunctionCalls (ServerName) WHERE ServerName is not null ON [StagingData]
GO

CREATE TABLE [dbo].[DateDimension](
	[DateKey] [int] NOT NULL,
	[Date] [date] NOT NULL,
	[Day] [tinyint] NOT NULL,
	[DaySuffix] [char](2) NOT NULL,
	[Weekday] [tinyint] NOT NULL,
	[WeekDayName] [varchar](10) NOT NULL,
	[IsWeekend] [bit] NOT NULL,
	[IsHoliday] [bit] NOT NULL,
	[HolidayText] [varchar](64) SPARSE  NULL,
	[DOWInMonth] [tinyint] NOT NULL,
	[DayOfYear] [smallint] NOT NULL,
	[WeekOfMonth] [tinyint] NOT NULL,
	[WeekOfYear] [tinyint] NOT NULL,
	[ISOWeekOfYear] [tinyint] NOT NULL,
	[Month] [tinyint] NOT NULL,
	[MonthName] [varchar](10) NOT NULL,
	[Quarter] [tinyint] NOT NULL,
	[QuarterName] [varchar](6) NOT NULL,
	[Year] [int] NOT NULL,
	[MMYYYY] [char](6) NOT NULL,
	[MonthYear] [char](7) NOT NULL,
	[FirstDayOfMonth] [date] NOT NULL,
	[LastDayOfMonth] [date] NOT NULL,
	[FirstDayOfQuarter] [date] NOT NULL,
	[LastDayOfQuarter] [date] NOT NULL,
	[FirstDayOfYear] [date] NOT NULL,
	[LastDayOfYear] [date] NOT NULL,
	[FirstDayOfNextMonth] [date] NOT NULL,
	[FirstDayOfNextYear] [date] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[DateKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [MasterData]
GO

CREATE TABLE [Staging].[VolumeInfo](
	[ServerName] [varchar](125) NOT NULL,
	[VolumeName] [varchar](125) NULL,
	[CapacityGB] [decimal](20, 2) NOT NULL,
	[UsedSpaceGB] [decimal](20, 2) NOT NULL,
	[UsedSpacePercent] [decimal](20, 2) NOT NULL,
	[FreeSpaceGB] [decimal](20, 2) NOT NULL,
	[Label] [varchar](125) NULL,
	[CollectionTime] [datetime2](7) NOT NULL
) ON [StagingData]
GO

ALTER TABLE [info].[Instance] ADD  DEFAULT ((0)) FOR [IsSQLClusterNode]
GO

ALTER TABLE [info].[Instance] ADD  DEFAULT ((0)) FOR [IsAlwaysOnNode]
GO

ALTER TABLE [info].[Instance] ADD  DEFAULT ((0)) FOR [IsDecommissioned]
GO

use SQLDBATools;
CREATE TABLE [Staging].[AOReplicaInfo]
(
	[clusterName] [varchar](125) NOT NULL,
	[agListenerName] [varchar](125) NULL,
	[replica_server_name] [varchar](125) NULL,
	[role_desc] [varchar](100) NULL,
	[failover_mode_desc] [varchar](100) NULL,
	[synchronization_health_desc] [varchar](100) NULL,
	[operational_state_desc] [varchar](100) NULL,
	[ConnectionState] [varchar](20) NOT NULL,
	[CollectionTime] [datetime] NOT NULL
)ON [StagingData]
go

use sqldbatools

CREATE TABLE Info.AlwaysOnListener
(
	ListenerName varchar(125) not null,
	DateAdded datetime2 default getdate()
)
go

CREATE TABLE [Staging].[JAMSEntry]
(
	[ServerName] varchar (50) NULL,
	[SetupID] [int] NOT NULL,
	[Setup] [varchar](125) NOT NULL,
	[JAMSEntry] [int] not NULL,
	[JobName] [varchar](125) NULL,
	[Description] [varchar](200) NULL,
	[CurrentState] [varchar](50) NULL,
	[TodaysDate] [datetime2](7) NULL,
	[HoldTime] [datetime2](7) NULL,
	[OriginalHoldTime] [datetime2](7) NULL,
	[ElapsedTime] [bigint] NULL,
	[CompletionTime] [datetime2](7) NULL,
	[FinalStatus] [varchar](50) NULL,
	[Held] [bit] NULL,
	[Stalled] [bit] NULL,
	[WaitFor] [bit] NULL,
	[StepWait] [bit] NULL,
	[Halted] [bit] NULL,
	[InitiatorType] [varchar](50) NULL,
	[SubmittedBy] [varchar](50) NULL,
	[CollectionTime] [datetime2](7) NULL
) ON StagingData
GO

CREATE TABLE [Staging].[JAMSEntry_History]
(
	[ServerName] varchar (50) NULL,
	[SetupID] [int] NOT NULL,
	[Setup] [varchar](125) NOT NULL,
	[JAMSEntry] [int] not NULL,
	[JobName] [varchar](125) NULL,
	[Description] [varchar](200) NULL,
	[CurrentState] [varchar](50) NULL,
	[TodaysDate] [datetime2](7) NULL,
	[HoldTime] [datetime2](7) NULL,
	[OriginalHoldTime] [datetime2](7) NULL,
	[ElapsedTime] [bigint] NULL,
	[CompletionTime] [datetime2](7) NULL,
	[FinalStatus] [varchar](50) NULL,
	[Held] [bit] NULL,
	[Stalled] [bit] NULL,
	[WaitFor] [bit] NULL,
	[StepWait] [bit] NULL,
	[Halted] [bit] NULL,
	[InitiatorType] [varchar](50) NULL,
	[SubmittedBy] [varchar](50) NULL,
	[CollectionTime] [datetime2](7) NULL
) ON StagingData
GO

CREATE PROCEDURE dbo.uspTruncateJAMSEntry
AS
BEGIN
	SET NOCOUNT ON;

	INSERT [Staging].[JAMSEntry_History]
	SELECT * FROM [Staging].[JAMSEntry];

	TRUNCATE TABLE [Staging].[JAMSEntry];
END
GO

CREATE FUNCTION [dbo].[Instance_Name]
	( @Instance_ID bigint )  
RETURNS SYSNAME  
AS
BEGIN   
    DECLARE @Name SYSNAME;
	SET @Name = (SELECT Name FROM [dbo].[Instance] WHERE [Instance_ID] = @Instance_ID);

    RETURN @Name;  
END  
GO

CREATE VIEW [info].[vw_DatabaseBackups]
AS
	SELECT	B.InstanceName as ServerInstance
			,B.[DatabaseName]
			,B.[DatabaseCreationDate]
			,B.[RecoveryModel]
			,[IsFullBackupInLast24Hours] = CASE	WHEN	[LastFullBackupDate] IS NULL OR DATEDIFF(HH,[LastFullBackupDate],GETDATE()) >= 24
												THEN	'No'
												ELSE	'Yes'
												END
			,[IsFullBackupInLast7Days] = CASE	WHEN	[LastFullBackupDate] IS NULL OR DATEDIFF(DD,[LastFullBackupDate],GETDATE()) >= 7
												THEN	'No'
												ELSE	'Yes'
												END
			,B.[LastFullBackupDate]
			,B.[LastDifferentialBackupDate]
			,B.[LastLogBackupDate]
			,B.[CollectionTime]
	FROM	[dbo].[DatabaseBackup] AS B	
	INNER JOIN
		(	SELECT MAX([BatchNumber]) AS [BatchNumber_Latest] FROM [dbo].[DatabaseBackup] ) AS L
		ON	L.BatchNumber_Latest = B.BatchNumber
GO


IF OBJECT_ID('Staging.usp_ETL_ServerInfo') IS NULL
	EXEC ('CREATE PROCEDURE Staging.usp_ETL_ServerInfo AS SELECT 1 AS Dummy;');
GO
ALTER PROCEDURE [Staging].[usp_ETL_ServerInfo]
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRAN

		/*	Create temp table */
		IF OBJECT_ID('tempdb..#StagingServerInfo') IS NOT NULL
			DROP TABLE #StagingServerInfo;
		SELECT	[NeedUpdate] = CASE WHEN m.FQDN IS NOT NULL THEN 1 ELSE 0 END,
				ServerName, EnvironmentType, s.FQDN, DNSHostName, IPAddress, Domain, OperatingSystem, SPVersion, 
				OSArchitecture, IsVM, Manufacturer, Model, RAM, CPU, PowerPlan, GeneralDescription, CollectionTime
				,ROW_NUMBER()OVER(PARTITION BY s.FQDN ORDER BY DNSHostName DESC, CollectionTime) AS RowID
		INTO	#StagingServerInfo
		FROM Staging.ServerInfo as s
		OUTER APPLY
			(SELECT m.FQDN from [Info].[Server] as m WHERE m.FQDN = s.FQDN) AS m
		WHERE s.FQDN IS NOT NULL
		AND IPAddress IS NOT NULL;

		/*	Add New Entries	*/
		;WITH CTE_AddNew AS (
			SELECT	ServerName, EnvironmentType, s.FQDN, DNSHostName, IPAddress, Domain, OperatingSystem, SPVersion, 
					OSArchitecture, IsVM, Manufacturer, Model, RAM, CPU, PowerPlan, GeneralDescription, CollectionTime, RowID
			FROM #StagingServerInfo as s
			WHERE [NeedUpdate] = 0
		)
		INSERT [Info].[Server]
		(	EnvironmentType, DNSHostName, FQDN, IPAddress, Domain, OperatingSystem, SPVersion, OSArchitecture, 
			IsVM, Manufacturer, Model, RAM, CPU, PowerPlan, GeneralDescription, CollectionTime)
		SELECT EnvironmentType, DNSHostName, FQDN, IPAddress, Domain = CASE WHEN Domain IS NULL THEN RIGHT(FQDN,LEN(FQDN)-CHARINDEX('.',FQDN)) ELSE Domain END, 
				OperatingSystem, SPVersion, OSArchitecture, IsVM, Manufacturer, Model, RAM, CPU, PowerPlan, GeneralDescription, CollectionTime
		FROM CTE_AddNew
		WHERE RowID = 1;

		/*	Update Old Entries	*/
		UPDATE I SET IPAddress = N.IPAddress
		FROM #StagingServerInfo as N INNER JOIN	[Info].[Server] as I ON	I.FQDN = N.FQDN	WHERE N.RowID = 1 AND N.[NeedUpdate] = 1
			AND N.IPAddress IS NOT NULL AND ISNULL(I.IPAddress,'') <> N.IPAddress;

		UPDATE I SET OperatingSystem = N.OperatingSystem
		FROM #StagingServerInfo as N INNER JOIN	[Info].[Server] as I ON	I.FQDN = N.FQDN	WHERE N.RowID = 1 AND N.[NeedUpdate] = 1
			AND N.OperatingSystem IS NOT NULL AND ISNULL(I.OperatingSystem,'') <> N.OperatingSystem;

		UPDATE I SET SPVersion = N.SPVersion
		FROM #StagingServerInfo as N INNER JOIN	[Info].[Server] as I ON	I.FQDN = N.FQDN	WHERE N.RowID = 1 AND N.[NeedUpdate] = 1
			AND N.SPVersion IS NOT NULL AND ISNULL(I.SPVersion,'') <> N.SPVersion;

		UPDATE I SET OSArchitecture = N.OSArchitecture
		FROM #StagingServerInfo as N INNER JOIN	[Info].[Server] as I ON	I.FQDN = N.FQDN	WHERE N.RowID = 1 AND N.[NeedUpdate] = 1
			AND N.OSArchitecture IS NOT NULL AND ISNULL(I.OSArchitecture,'') <> N.OSArchitecture;

		UPDATE I SET IsVM = N.IsVM
		FROM #StagingServerInfo as N INNER JOIN	[Info].[Server] as I ON	I.FQDN = N.FQDN	WHERE N.RowID = 1 AND N.[NeedUpdate] = 1
			AND N.IsVM IS NOT NULL AND ISNULL(I.IsVM,'') <> N.IsVM;

		UPDATE I SET Manufacturer = N.Manufacturer
		FROM #StagingServerInfo as N INNER JOIN	[Info].[Server] as I ON	I.FQDN = N.FQDN	WHERE N.RowID = 1 AND N.[NeedUpdate] = 1
			AND N.Manufacturer IS NOT NULL AND ISNULL(I.Manufacturer,'') <> N.Manufacturer;

		UPDATE I SET Model = N.Model
		FROM #StagingServerInfo as N INNER JOIN	[Info].[Server] as I ON	I.FQDN = N.FQDN	WHERE N.RowID = 1 AND N.[NeedUpdate] = 1
			AND N.Model IS NOT NULL AND ISNULL(I.Model,'') <> N.Model;

		UPDATE I SET RAM = N.RAM
		FROM #StagingServerInfo as N INNER JOIN	[Info].[Server] as I ON	I.FQDN = N.FQDN	WHERE N.RowID = 1 AND N.[NeedUpdate] = 1
			AND N.RAM IS NOT NULL AND ISNULL(I.RAM,'') <> N.RAM;

		UPDATE I SET CPU = N.CPU
		FROM #StagingServerInfo as N INNER JOIN	[Info].[Server] as I ON	I.FQDN = N.FQDN	WHERE N.RowID = 1 AND N.[NeedUpdate] = 1
			AND N.CPU IS NOT NULL AND ISNULL(I.CPU,'') <> N.CPU;

		UPDATE I SET PowerPlan = N.PowerPlan
		FROM #StagingServerInfo as N INNER JOIN	[Info].[Server] as I ON	I.FQDN = N.FQDN	WHERE N.RowID = 1 AND N.[NeedUpdate] = 1
			AND N.PowerPlan IS NOT NULL AND ISNULL(I.PowerPlan,'') <> N.PowerPlan;

		UPDATE I SET GeneralDescription = N.GeneralDescription
		FROM #StagingServerInfo as N INNER JOIN	[Info].[Server] as I ON	I.FQDN = N.FQDN	WHERE N.RowID = 1 AND N.[NeedUpdate] = 1
			AND N.GeneralDescription IS NOT NULL AND ISNULL(I.GeneralDescription,'') <> N.GeneralDescription;

		UPDATE I SET UpdatedDate = N.CollectionTime
		FROM #StagingServerInfo as N INNER JOIN	[Info].[Server] as I ON	I.FQDN = N.FQDN	WHERE N.RowID = 1 AND N.[NeedUpdate] = 1
			AND (	(N.Manufacturer IS NOT NULL AND ISNULL(I.Manufacturer,'') <> N.Manufacturer)
				OR	(N.GeneralDescription IS NOT NULL AND ISNULL(I.GeneralDescription,'') <> N.GeneralDescription)
				OR	(N.PowerPlan IS NOT NULL AND ISNULL(I.PowerPlan,'') <> N.PowerPlan)
				OR	(N.CPU IS NOT NULL AND ISNULL(I.CPU,'') <> N.CPU)
				OR	(N.RAM IS NOT NULL AND ISNULL(I.RAM,'') <> N.RAM)
				OR	(N.Model IS NOT NULL AND ISNULL(I.Model,'') <> N.Model)
				OR	(N.IsVM IS NOT NULL AND ISNULL(I.IsVM,'') <> N.IsVM)
				OR	(N.OSArchitecture IS NOT NULL AND ISNULL(I.OSArchitecture,'') <> N.OSArchitecture)
				OR	(N.SPVersion IS NOT NULL AND ISNULL(I.SPVersion,'') <> N.SPVersion)
				OR	(N.OperatingSystem IS NOT NULL AND ISNULL(I.OperatingSystem,'') <> N.OperatingSystem)
				OR	(N.IPAddress IS NOT NULL AND ISNULL(I.IPAddress,'') <> N.IPAddress)
				)

		DELETE [Staging].[ServerInfo]
			WHERE FQDN IN (SELECT i.FQDN FROM [Info].[Server] AS i)
			OR FQDN is null
			OR IPAddress IS NULL
	COMMIT TRAN
END
GO

IF OBJECT_ID('Staging.usp_ETL_SqlInstanceInfo') IS NULL
	EXEC ('CREATE PROCEDURE Staging.usp_ETL_SqlInstanceInfo AS SELECT 1 AS Dummy;');
GO
ALTER PROCEDURE Staging.usp_ETL_SqlInstanceInfo
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRAN
		;WITH CTE AS (
			SELECT FQDN, ServerName, 
					InstanceName = CASE WHEN CHARINDEX('.',InstanceName) > 0 AND CHARINDEX('\',InstanceName) > 0
										THEN LEFT([FQDN],CHARINDEX('.',[FQDN])-1) + '\' + RIGHT(InstanceName,LEN(InstanceName)-charindex('\',InstanceName)) 
										WHEN CHARINDEX('.',InstanceName) > 0
										THEN LEFT([FQDN],CHARINDEX('.',[FQDN])-1) 
										ELSE InstanceName 
									END, 
					InstallDataDirectory, Version, Edition, ProductKey, 
					IsClustered, IsCaseSensitive, IsHadrEnabled, IsDecommissioned, IsPowerShellLinked, CollectionTime
					,ROW_NUMBER()OVER(PARTITION BY InstanceName ORDER BY FQDN, InstanceName) AS RowID
			FROM Staging.InstanceInfo
			WHERE InstanceName IS NOT NULL
			AND FQDN IN (SELECT m.FQDN from [Info].[Server] as m)
		)
		INSERT [Info].[Instance]
		(FQDN, InstanceName, ServerID, InstallDataDirectory, Version, Edition, ProductKey, IsClustered, 
			IsCaseSensitive, IsHadrEnabled, IsDecommissioned, IsPowerShellLinked, CollectionTime
		)
		SELECT ct.FQDN, ct.InstanceName, s.ServerID, ct.InstallDataDirectory, ct.Version, ct.Edition, ct.ProductKey, ct.IsClustered, 
			ct.IsCaseSensitive, ct.IsHadrEnabled, ct.IsDecommissioned, ct.IsPowerShellLinked, ct.CollectionTime
		FROM CTE AS ct
		inner join
			Info.Server as s
			on s.FQDN = ct.FQDN
		WHERE RowID = 1
		AND ct.InstanceName NOT IN (SELECT i.InstanceName FROM Info.Instance as i);

		WITH CTE AS (
			SELECT FQDN, ServerName, 
					InstanceName = CASE WHEN CHARINDEX('.',InstanceName) > 0 AND CHARINDEX('\',InstanceName) > 0
										THEN LEFT([FQDN],CHARINDEX('.',[FQDN])-1) + '\' + RIGHT(InstanceName,LEN(InstanceName)-charindex('\',InstanceName)) 
										WHEN CHARINDEX('.',InstanceName) > 0
										THEN LEFT([FQDN],CHARINDEX('.',[FQDN])-1) 
										ELSE InstanceName 
									END, 
					InstallDataDirectory, Version, Edition, ProductKey, 
					IsClustered, IsCaseSensitive, IsHadrEnabled, IsDecommissioned, IsPowerShellLinked, CollectionTime
					,ROW_NUMBER()OVER(PARTITION BY InstanceName ORDER BY FQDN, InstanceName) AS RowID
			FROM Staging.InstanceInfo
			WHERE InstanceName IS NOT NULL
			AND FQDN IN (SELECT m.FQDN from [Info].[Server] as m)
		)
		DELETE CTE
			WHERE InstanceName IN (SELECT i.InstanceName FROM [Info].[Instance] AS i);
	COMMIT TRAN
END
GO

IF OBJECT_ID('Staging.usp_ETL_ApplicationInfo') IS NULL
	EXEC ('CREATE PROCEDURE Staging.usp_ETL_ApplicationInfo AS SELECT 1 AS Dummy;');
GO
ALTER PROCEDURE Staging.usp_ETL_ApplicationInfo
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRAN
		;WITH CTE AS (
			SELECT	ApplicationName, BusinessUnit, Product, Priority, Owner_EmailId, DelegatedOwner_EmailId, 
					OwnershipDelegationEndDate, PrimaryContact_EmailId, SecondaryContact_EmailId, 
					SecondaryContact2_EmailId, CollectionTime
					,ROW_NUMBER()OVER(PARTITION BY ApplicationName,BusinessUnit, Product ORDER BY CollectionTime DESC) AS RowID
			FROM Staging.ApplicationInfo as s
			WHERE ApplicationName IS NOT NULL
			AND NOT EXISTS (SELECT * FROM [Info].[Application] AS i WHERE i.ApplicationName = s.ApplicationName
											AND i.BusinessUnit = s.BusinessUnit AND i.Product = s.Product
							)
		)
		INSERT [Info].[Application]
		(	ApplicationName, BusinessUnit, Product, Priority, Owner_EmailId, DelegatedOwner_EmailId, 
					OwnershipDelegationEndDate, PrimaryContact_EmailId, SecondaryContact_EmailId, 
					SecondaryContact2_EmailId, CollectionTime
		)
		SELECT ApplicationName, BusinessUnit, Product, Priority, Owner_EmailId, DelegatedOwner_EmailId, 
					OwnershipDelegationEndDate, PrimaryContact_EmailId, SecondaryContact_EmailId, 
					SecondaryContact2_EmailId, CollectionTime
		FROM CTE AS ct
		WHERE RowID = 1;

		DELETE s
		FROM Staging.ApplicationInfo AS s
		INNER JOIN
			[Info].[Application] AS i
			ON i.ApplicationName = s.ApplicationName
				AND i.BusinessUnit = s.BusinessUnit AND i.Product = s.Product;
	COMMIT TRAN
END
GO

USE SQLDBATools;
GO
IF OBJECT_ID('Staging.usp_ETL_VolumeInfo') IS NULL
	EXEC ('CREATE PROCEDURE Staging.usp_ETL_VolumeInfo AS SELECT 1 AS Dummy;');
GO
ALTER PROCEDURE [Staging].[usp_ETL_VolumeInfo]
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRAN
		-- Truncate table
		TRUNCATE TABLE dbo.VolumeInfo;

		;WITH CTE AS (
			SELECT ServerName, VolumeName, CapacityGB, UsedSpaceGB, UsedSpacePercent, FreeSpaceGB, Label, CollectionTime
					,ROW_NUMBER()OVER(PARTITION BY ServerName, VolumeName ORDER BY ServerName, VolumeName) AS RowID
			FROM Staging.VolumeInfo
			WHERE ServerName IS NOT NULL
		)
		INSERT dbo.VolumeInfo
		(ServerName, VolumeName, CapacityGB, UsedSpaceGB, UsedSpacePercent, FreeSpaceGB, Label, CollectionTime)
		SELECT ServerName, VolumeName, CapacityGB, UsedSpaceGB, UsedSpacePercent, FreeSpaceGB, Label, CollectionTime
		FROM CTE
		WHERE RowID = 1;

		DELETE o
		FROM [Staging].VolumeInfo AS o
		WHERE EXISTS (SELECT i.ServerName FROM dbo.VolumeInfo AS i WHERE i.ServerName = o.ServerName AND i.VolumeName = o.VolumeName);
	COMMIT TRAN
END
GO  

IF OBJECT_ID('Staging.usp_ETL_DatabaseBackup') IS NULL
	EXEC ('CREATE PROCEDURE Staging.usp_ETL_DatabaseBackup AS SELECT 1 AS Dummy;');
GO
ALTER PROCEDURE Staging.usp_ETL_DatabaseBackup
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @_BatchNumber BIGINT;

	SET @_BatchNumber = ISNULL((SELECT MAX([BatchNumber]) FROM [dbo].[DatabaseBackup]),0) + 1;

	;WITH CTE AS 
	(	SELECT I.InstanceID, I.InstanceName, DatabaseName, DatabaseCreationDate, RecoveryModel, 
				LastFullBackupDate, LastDifferentialBackupDate, LastLogBackupDate, S.[CollectionTime] ,@_BatchNumber AS BatchNumber
				,ROW_NUMBER()OVER(PARTITION BY CAST(S.[CollectionTime] AS smalldatetime), I.InstanceName, DatabaseName ORDER BY DatabaseCreationDate) AS RowID
		FROM	[Staging].[DatabaseBackups] AS S
		INNER JOIN
				[info].[Instance] AS I
			ON	I.InstanceName = S.ServerName
		WHERE	NOT EXISTS (SELECT * FROM [dbo].[DatabaseBackup] as b WHERE DATEDIFF(MINUTE,b.CollectionTime,S.CollectionTime) < 2
									AND b.InstanceID = I.InstanceID AND b.DatabaseName = S.DatabaseName)
	)
	INSERT [dbo].[DatabaseBackup]
	(	InstanceID, InstanceName, DatabaseName, DatabaseCreationDate, RecoveryModel, 
		LastFullBackupDate, LastDifferentialBackupDate, LastLogBackupDate, CollectionTime, BatchNumber)
	SELECT	InstanceID, InstanceName, DatabaseName, DatabaseCreationDate, RecoveryModel, 
			LastFullBackupDate, LastDifferentialBackupDate, LastLogBackupDate, [CollectionTime] ,BatchNumber
	FROM	CTE
	WHERE	RowID = 1;

	TRUNCATE TABLE [Staging].[DatabaseBackups];
END
GO

IF OBJECT_ID('dbo.vw_DatabaseBackups') IS NULL
	EXEC ('CREATE VIEW dbo.vw_DatabaseBackups AS SELECT 1 AS [Message]');
GO
ALTER VIEW dbo.vw_DatabaseBackups
AS
	SELECT	I.Name as ServerInstance
			,B.[DatabaseName]
			,B.[DatabaseCreationDate]
			,B.[RecoveryModel]
			,[IsFullBackupInLast24Hours] = CASE	WHEN	[LastFullBackupDate] IS NULL OR DATEDIFF(HH,[LastFullBackupDate],GETDATE()) >= 24
												THEN	'No'
												ELSE	'Yes'
												END
			,[IsFullBackupInLast7Days] = CASE	WHEN	[LastFullBackupDate] IS NULL OR DATEDIFF(DD,[LastFullBackupDate],GETDATE()) >= 7
												THEN	'No'
												ELSE	'Yes'
												END
			,B.[LastFullBackupDate]
			,B.[LastDifferentialBackupDate]
			,B.[LastLogBackupDate]
			,B.[CollectionTime]
	FROM	[dbo].[DatabaseBackup] AS B	
	INNER JOIN
		(	SELECT MAX([BatchNumber]) AS [BatchNumber_Latest] FROM [dbo].[DatabaseBackup] ) AS L
		ON	L.BatchNumber_Latest = B.BatchNumber
	INNER JOIN
			[dbo].[Instance] AS I
		ON	I.Instance_ID = B.Instance_ID
GO

IF OBJECT_ID('dbo.Instance_Name') IS NULL
	EXEC ('CREATE FUNCTION dbo.Instance_Name RETURNS BIT AS BEGIN RETURN 1 END');
GO
ALTER FUNCTION dbo.Instance_Name
	( @Instance_ID bigint )  
RETURNS SYSNAME  
AS
BEGIN   
    DECLARE @Name SYSNAME;
	SET @Name = (SELECT Name FROM [dbo].[Instance] WHERE [Instance_ID] = @Instance_ID);

    RETURN @Name;  
END  
GO

CREATE NONCLUSTERED INDEX NCI_DatabaseBackup_BatchNumber
	ON [dbo].[DatabaseBackup] ([BatchNumber])
GO

--SELECT * FROM dbo.vw_DatabaseBackups;

DECLARE @tableHTML  NVARCHAR(MAX) ;
DECLARE @subject VARCHAR(200);

SET @subject = 'Database Backup History - '+CAST(CAST(GETDATE() AS DATE) AS VARCHAR(20));
--SELECT @subject

SET @tableHTML =  N'
<style>
#BackupHistory {
    font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
    border-collapse: collapse;
    width: 100%;
}

#BackupHistory td, #BackupHistory th {
    border: 1px solid #ddd;
    padding: 8px;
}

#BackupHistory tr:nth-child(even){background-color: #f2f2f2;}

#BackupHistory tr:hover {background-color: #ddd;}

#BackupHistory th {
    padding-top: 12px;
    padding-bottom: 12px;
    text-align: left;
    background-color: #4CAF50;
    color: white;
}
</style>'+
    N'<H1>'+@subject+'</H1>' +  
    N'<table border="1" id="BackupHistory">' +  
    N'<tr>
	<th>ServerInstance</th>' + 
		N'<th>DatabaseName</th>' +  
		N'<th>DatabaseCreationDate</th>'+
		N'<th>RecoveryModel</th>'+
		N'<th>HasFullBackup<br>InLast24Hours</th>' +  
		N'<th>IsFullBackup<br>InLast7Days</th>' + 
		N'<th>LastFullBackupDate</th>'+
		N'<th>LastDifferential<br>BackupDate</th>' +  
		N'<th>LastLogBackupDate</th>'+
		N'<th>CollectionTime</th>
	</tr>' +  
    CAST ( ( SELECT td = ServerInstance, '',  
                    td = DatabaseName, '',  
                    td = DatabaseCreationDate, '',  
                    td = RecoveryModel, '',  
                    td = IsFullBackupInLast24Hours, '',  
					td = IsFullBackupInLast7Days, '', 					
					td = ISNULL(CAST(LastFullBackupDate AS varchar(100)),' '), '', 
					td = ISNULL(CAST(LastDifferentialBackupDate AS varchar(100)),' '), '', 
					td = ISNULL(CAST(LastLogBackupDate AS varchar(100)),' '), '',
                    td = CollectionTime  
              FROM dbo.vw_DatabaseBackups as b
				WHERE b.IsFullBackupInLast24Hours = 'No'  
              FOR XML PATH('tr'), TYPE   
    ) AS NVARCHAR(MAX) ) +  
    N'</table>' ;  

EXEC msdb.dbo.sp_send_dbmail 
	@recipients='ajay.dwivedi@contso.com',--;Anant.Dwivedi@contso.com',  
    @subject = @subject,  
    @body = @tableHTML,  
    @body_format = 'HTML' ; 
GO
