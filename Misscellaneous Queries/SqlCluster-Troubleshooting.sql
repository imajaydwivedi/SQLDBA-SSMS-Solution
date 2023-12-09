Get-ClusterLog -Cluster sqlclusteradmin -TimeSpan 30 -UseLocalTime -Destination 'c:\temp\clusterLogs'

select * from sys.dm_os_cluster_nodes

/*	Force Start Cluster without Quorum	*/

/*	Re-configure Quorum configuration, and remove vote for cluster nodes that are down */

/*	Perform Manual Forced Failover 
	Should be executed on Node that will become Primary */
	ALTER AVAILABILITY GROUP [SqlAg] FORCE_FAILOVER_ALLOW_DATA_LOSS;
	GO

/* Query to Resume databases on Secondary Replicas after Forced Manual Failover */
	declare @dbName varchar(500);
	declare @tsqlQuery nvarchar(max);
	declare cur_dbs cursor for 
		select database_name from sys.availability_databases_cluster

	open cur_dbs
	fetch cur_dbs into @dbName

	while @@FETCH_STATUS = 0
	begin
		print @dbName

		set @tsqlQuery = 'alter database '+QUOTENAME(@dbName)+' set hadr resume;'
		exec(@tsqlQuery);

		fetch cur_dbs into @dbName	
	end
	close cur_dbs
	deallocate cur_dbs
	go