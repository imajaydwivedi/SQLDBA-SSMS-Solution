--	SqlAGNetworkName
SELECT cluster_name	,quorum_state_desc FROM sys.dm_hadr_cluster
GO
--SELECT dns_name, port from sys.availability_group_listeners
--go

SELECT	cl.cluster_name
		,ag.dns_name as ag_Listener
		,ar.replica_server_name
		,ars.role_desc
		,ar.failover_mode_desc
		,ars.synchronization_health_desc
		,ars.operational_state_desc
		,CASE ars.connected_state
			WHEN 0
				THEN 'Disconnected'
			WHEN 1
				THEN 'Connected'
			ELSE ''
			END AS ConnectionState
		,getdate() as CollectionTime
into tempdb..ReplicaInfo
FROM sys.dm_hadr_availability_replica_states ars
INNER JOIN sys.availability_replicas ar ON ars.replica_id = ar.replica_id
	AND ars.group_id = ar.group_id
CROSS JOIN
	sys.dm_hadr_cluster AS cl
CROSS JOIN
	sys.availability_group_listeners AS ag
GO

SELECT DISTINCT rcs.database_name
	,ar.replica_server_name
	,drs.synchronization_state_desc
	,drs.synchronization_health_desc
	,CASE rcs.is_failover_ready
		WHEN 0
			THEN 'Data Loss'
		WHEN 1
			THEN 'No Data Loss'
		ELSE ''
		END AS FailoverReady
FROM sys.dm_hadr_database_replica_states drs
INNER JOIN sys.availability_replicas ar ON drs.replica_id = ar.replica_id
	AND drs.group_id = ar.group_id
INNER JOIN sys.dm_hadr_database_replica_cluster_states rcs ON drs.replica_id = rcs.replica_id
ORDER BY replica_server_name

/*
select * from Info.Instance as i
	where i.IsHadrEnabled = 1

use SQLDBATools;
insert Info.AlwaysOnListener
(ListenerName, DateAdded)
values ('SqlAGNetworkName',DEFAULT)
go
*/