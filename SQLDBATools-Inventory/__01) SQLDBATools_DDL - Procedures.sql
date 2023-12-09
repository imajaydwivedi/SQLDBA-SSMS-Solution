USE SQLDBATools
GO

CREATE PROCEDURE [Staging].[usp_ETL_ServerInfo]
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRAN

		/*	Create temp table */
		IF OBJECT_ID('tempdb..#StagingServerInfo') IS NOT NULL
			DROP TABLE #StagingServerInfo;
		SELECT	[NeedUpdate] = CASE WHEN m.FQDN IS NOT NULL THEN 1 ELSE 0 END,
				s.*
				,ROW_NUMBER()OVER(PARTITION BY s.FQDN ORDER BY ServerName DESC, CollectionDate) AS RowID
		INTO	#StagingServerInfo
		FROM Staging.ServerInfo as s
		OUTER APPLY
			(SELECT m.FQDN from [dbo].[Server] as m WHERE m.FQDN = s.FQDN) AS m
		WHERE s.FQDN IS NOT NULL
		AND IPAddress IS NOT NULL;

		/*	Add New Entries	*/
		;WITH CTE_AddNew AS (
			SELECT	s.*, srv.ParentServerId
			FROM #StagingServerInfo as s
			OUTER APPLY( SELECT srv.ServerID as ParentServerId FROM dbo.Server as srv where srv.ServerName = s.ParentServerName) as srv
			WHERE [NeedUpdate] = 0
		)
		INSERT [dbo].[Server]
		( ServerName, ApplicationId, EnvironmentType, FQDN, IPAddress, Domain, IsStandaloneServer, IsSqlClusterNode, IsAgNode, IsWSFC, IsSqlCluster, IsAG, ParentServerId, OS, SPVersion, IsVM, IsPhysical, Manufacturer, Model, RAM, CPU, Powerplan, OSArchitecture, ISDecom, DecomDate, GeneralDescription, CollectionDate, CollectedBy, UpdatedDate, UpdatedBy	
		)
		SELECT ServerName, ApplicationId, EnvironmentType, FQDN, IPAddress, Domain, IsStandaloneServer, IsSqlClusterNode, IsAgNode, IsWSFC, IsSqlCluster, IsAG, ParentServerId, OS, SPVersion, IsVM, IsPhysical, Manufacturer, Model, RAM, CPU, Powerplan, OSArchitecture, ISDecom, DecomDate, GeneralDescription, CollectionDate, CollectedBy, UpdatedDate, UpdatedBy
		--SELECT EnvironmentType, DNSHostName, FQDN, IPAddress, Domain = CASE WHEN Domain IS NULL THEN RIGHT(FQDN,LEN(FQDN)-CHARINDEX('.',FQDN)) ELSE Domain END, 
		--		OperatingSystem, SPVersion, OSArchitecture, IsVM, Manufacturer, Model, RAM, CPU, PowerPlan, GeneralDescription, CollectionTime
		FROM CTE_AddNew
		WHERE RowID = 1;

		/*	Update Old Entries	*/
		/*
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
		*/
	
		/* Update ParentServerID */
		UPDATE srv
		SET ParentServerId = i2.ServerID
		--SELECT	srv.ServerName, srv.FQDN, i1.ParentServerName,i2.ServerID
		FROM	dbo.Server as srv
		JOIN	Staging.ServerInfo as i1
			ON	srv.FQDN = i1.FQDN
		JOIN	dbo.Server as i2
			ON	i1.ParentServerName = i2.ServerName
		WHERE	i1.ParentServerName IS NOT NULL

		DELETE [Staging].[ServerInfo]
			WHERE FQDN IN (SELECT i.FQDN FROM [dbo].[Server] AS i)
			--OR FQDN is null
			--OR IPAddress IS NULL

	COMMIT TRAN
	
END
GO


USE SQLDBATools
GO
CREATE PROCEDURE [Staging].[usp_ETL_InstanceInfo]
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRAN

		;WITH T_InstanceInfo AS
		(
			SELECT	s.ServerID, inf.SqlInstance, inf.InstanceName,
					inf.RootDirectory, inf.Version, inf.CommonVersion,
					inf.Build, inf.VersionString, inf.Edition,
					inf.Collation, inf.ProductKey, inf.DefaultDataLocation,
					inf.DefaultLogLocation, inf.DefaultBackupLocation, inf.ErrorLogPath,
					inf.ServiceAccount, inf.Port, inf.IsStandaloneInstance, 
					inf.IsSQLCluster, inf.IsAGListener, inf.IsAGNode,
					inf.AGListenerName, inf.HasOtherHASetup, inf.HARole,
					inf.HAPartner, inf.IsPowershellLinked, inf.IsDecom, 
					inf.DecomDate, inf.CollectionDate, inf.CollectedBy,
					inf.UpdatedDate, inf.UpdatedBy, inf.Remark1, inf.Remark2
			FROM	Staging.InstanceInfo as inf
			LEFT JOIN
					dbo.Server as s
				ON	inf.ServerName = s.ServerName
			WHERE inf.SqlInstance not in (select i.SqlInstance from dbo.Instance as i)
		)
		INSERT dbo.Instance
		([ServerID]      ,[SqlInstance]      ,[InstanceName]
		,[RootDirectory]      ,[Version]      ,[CommonVersion]
		,[Build]      ,[VersionString]      ,[Edition]
		,[Collation]      ,[ProductKey]      ,[DefaultDataLocation]
		,[DefaultLogLocation]      ,[DefaultBackupLocation]      ,[ErrorLogPath]
		,[ServiceAccount]      ,[Port]      ,[IsStandaloneInstance]
		,[IsSQLCluster]      ,[IsAGListener]      ,[IsAGNode]
		,[AGListener]      ,[HasOtherHASetup]      ,[HARole]
		,[HAPartner]      ,[IsPowershellLinked]      ,[IsDecom]
		,[DecomDate]      ,[CollectionDate]      ,[CollectedBy]
		,[UpdatedDate]      ,[UpdatedBy]      ,[Remark1]
		,[Remark2]
		)
		SELECT * FROM T_InstanceInfo;

		TRUNCATE TABLE Staging.InstanceInfo;

	COMMIT TRAN

END
GO