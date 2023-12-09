SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SELECT ar.replica_server_name AS server_name,
			drs.is_primary_replica,
       adc.database_name,
       ag.name AS ag_name,
       drs.is_local,
       drs.synchronization_state_desc AS sync_desc,
       drs.synchronization_health_desc AS sync_health,
       drs.last_redone_time,
       drs.log_send_queue_size,
       drs.log_send_rate,
       drs.redo_queue_size,
       drs.redo_rate,
       (drs.redo_queue_size / drs.redo_rate) / 60.0 AS estimated_redo_completion_time_min,
       drs.last_commit_time
  FROM sys.dm_hadr_database_replica_states AS drs
 INNER JOIN sys.availability_databases_cluster AS adc
    ON drs.group_id          = adc.group_id
   AND drs.group_database_id = adc.group_database_id
 INNER JOIN sys.availability_groups AS ag
    ON ag.group_id           = drs.group_id
 INNER JOIN sys.availability_replicas AS ar
    ON drs.group_id          = ar.group_id
   AND drs.replica_id        = ar.replica_id
 --WHERE drs.is_local = 1 and drs.is_primary_replica <> 1
	--and adc.database_name in ('StackOverflow','stp')
 ORDER BY ag.name, ar.replica_server_name, adc.database_name;


select * from sys.availability_groups
select * from sys.availability_replicas
select * from sys.availability_read_only_routing_lists
select * from sys.availability_group_listeners
select * from sys.databases where replica_id is not null

select * from sys.dm_hadr_availability_replica_states
select * from sys.dm_hadr_database_replica_states
select * from sys.dm_hadr_cluster
select * from sys.dm_hadr_auto_page_repair


SELECT ag.name AS 'AG Name'
	,ar.replica_server_name AS 'Replica Instance'
	,d.name as 'Database Name'
	,Location = CASE
		WHEN ar_state.is_local = 1
			THEN N'LOCAL'
		ELSE 'REMOTE'
		END
	,ROLE = CASE
		WHEN ar_state.role_desc IS NULL
			THEN N'DISCONNECTED'
		ELSE ar_state.role_desc
		END
	,ar_state.connected_state_desc AS 'Connection State'
	,ar.availability_mode_desc AS 'Mode'
	,dr_state.synchronization_state_desc AS 'State'
FROM (
	(
		sys.availability_groups AS ag JOIN sys.availability_replicas AS ar ON ag.group_id = ar.group_id
		) JOIN sys.dm_hadr_availability_replica_states AS ar_state ON ar.replica_id = ar_state.replica_id
	)
JOIN sys.dm_hadr_database_replica_states dr_state ON ag.group_id = dr_state.group_id
	AND dr_state.replica_id = ar_state.replica_id
JOIN sys.databases d ON d.database_id = dr_state.database_id


SELECT ag.name AS 'AG Name'
	,ar.replica_server_name AS 'Replica Instance'
	,dr_state.database_id AS 'Database ID'
	,Location = CASE
		WHEN ar_state.is_local = 1
			THEN N'LOCAL'
		ELSE 'REMOTE'
		END
	,ROLE = CASE
		WHEN ar_state.role_desc IS NULL
			THEN N'DISCONNECTED'
		ELSE ar_state.role_desc
		END
	,dr_state.log_send_queue_size AS 'Log Send Queue Size'
	,dr_state.redo_queue_size AS 'Redo Queue Size'
	,dr_state.log_send_rate AS 'Log Send Rate'
	,dr_state.redo_rate AS 'Redo Rate'
FROM (
	(
		sys.availability_groups AS ag JOIN sys.availability_replicas AS ar ON ag.group_id = ar.group_id
		) JOIN sys.dm_hadr_availability_replica_states AS ar_state ON ar.replica_id = ar_state.replica_id
	)
JOIN sys.dm_hadr_database_replica_states dr_state ON ag.group_id = dr_state.group_id
	AND dr_state.replica_id = ar_state.replica_id;


SELECT * FROM sys.dm_os_wait_stats
WHERE wait_type LIKE '%HADR%'
ORDER BY wait_time_ms DESC;

