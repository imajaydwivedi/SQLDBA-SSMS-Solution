use SQLDBATools
GO

/* All errors that are still to Resolve */
select ServerName, Error, Command from [Staging].[CollectionErrors]
	where ServerName like '%Skype%' and Cmdlet = 'Get-SQLInstanceInfo'  

select * from DBA.[dbo].[Vw_UnauthorizedServerRoleMembers]
SELECT * FROM [dbo].[ServerRoleMemberException]
exec dba..[usp_SecurityCheck]
select * from [Staging].[CollectionErrors] where Cmdlet = 'Test-WSMan'
select * from SQLDBATools.Staging.SecurityCheckInfo -- 929
truncate table  Staging.SecurityCheckInfo -- 929
delete from [Staging].[CollectionErrors] where Cmdlet = 'Collect-SecurityCheckInfo'


SELECT * FROM [Info].[Server] as S where S.FQDN like 'ACCOUNTING%'
SELECT * FROM [Info].[Instance] AS I WHERE I.FQDN like 'ACCOUNTING%'
/* add below columns more:-
SQLServiceAccount, SQLService, SQLServiceStartMode, BrowserAccount, BrowserStartMode, CostThresholdForParallelism, MaxDegreeOfParallelism, DBMailEnabled, DefaultBackupCComp, MaxMem, MinMem, RemoteDacEnabled, XPCmdShellEnabled, DefaultFile, DefaultLog, ErrorLogPath, InstallDataDirectory, InstallSharedDirectory, IsFullTextInstalled, LoginMode, MasterDBLogPath, MasterDBPath, OptimizeAdhocWorkloads, AGListener, AGs, AgentServiceAccount, AgentServiceStartMode
*/

select * from [Info].[Application]
select * from [info].[Xref_ApplicationServer]

SELECT COUNT(*) FROM Info.Server --164
SELECT COUNT(*) FROM Staging.ServerInfo with(nolock)--0

SELECT * FROM Info.Server --164
SELECT * FROM Staging.ServerInfo with(nolock)--0

SELECT COUNT(*) FROM Info.Instance --120
SELECT COUNT(*) FROM Staging.InstanceInfo --0

select s.ServerID, s.ServerName, s.EnvironmentType, s.DNSHostName, s.FQDN, s.IPAddress, 
		s.Domain, s.OperatingSystem, s.SPVersion, s.IsVM, s.Manufacturer, s.Model, s.RAM, 
		s.CPU, s.CollectionTime, s.GeneralDescription,
		i.InstanceID, i.InstanceName, i.InstallDataDirectory, i.Version, i.Edition, i.ProductKey, 
		i.IsClustered, i.IsCaseSensitive, i.IsHadrEnabled, i.IsDecommissioned, i.IsPowerShellLinked
from Info.Server as s
left join
	Info.Instance as i
	on i.FQDN = s.FQDN
go

select * from Info.Server as s where s.FQDN = 'ServerName.contso.com'
select * from Info.Instance as s where s.FQDN = 'ServerName.contso.com'

/*
UPDATE Info.Server
SET Domain = RIGHT(FQDN,LEN(FQDN)-CHARINDEX('.',FQDN)) 
WHERE Domain IS NULL
*/

select * from Info.Instance as i
	where i.IsHadrEnabled = 1

use SQLDBATools;
select * from Info.AlwaysOnListener;

insert Info.AlwaysOnListener
(ListenerName, DateAdded)
values ('ServerName',DEFAULT)
go

truncate table [Staging].[AOReplicaInfo];
select * from [Staging].[AOReplicaInfo] 
	WHERE synchronization_health_desc <> 'HEALTHY' OR ConnectionState <> 'Connected'

exec dbo.usp_GetMail_4_SQLDBATools

USE SQLDBATools;
select * from Staging.JAMSEntry