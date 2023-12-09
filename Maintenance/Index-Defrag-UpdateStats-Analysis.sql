USE DBA
go

SET NOCOUNT ON;

declare @FragmentationLevel1 int = 20

--	Code for IndexOptimize_Modified
select	db_name(ips.database_id) as DbName,
		sch.name as SchemaName,
		object_name(ips.object_id) as TableName,
		ind.name as IndexName,
		ips.page_count as TotalPages,
		0 as UsedPages
from sys.dm_db_index_physical_stats(DB_ID(),NULL,NULL,NULL,'LIMITED') as ips -- yes
inner join sys.indexes as ind on ips.index_id = ind.index_id and ips.object_id = ind.object_id -- yes
inner join sys.tables as tbl on ips.object_id = tbl.object_id
inner join sys.schemas as sch on tbl.schema_id = sch.schema_id -- yes
inner join sys.dm_db_partition_stats as ps on ps.object_id = ips.object_id and ps.index_id = ips.index_id
left join sys.stats as sts on sts.object_id = ind.object_id
cross apply sys.dm_db_stats_properties(ind.object_id, sts.stats_id) as sp
where sts.name = ind.name
AND (	(	(case when ips.page_count >= 1000 then 'Yes' else 'No' end) = 'Yes'
			and avg_fragmentation_in_percent >= @FragmentationLevel1
		)
		-- Index Defrag Filters
		OR
		-- Update Stats filter
		(	(case when sp.modification_counter > 0 then 'Yes' else 'No' end) = 'Yes'
			and (case when sp.modification_counter >= SQRT(ps.row_count * 1000) then 'Yes' else 'No' end) = 'Yes'
		)
	)

--and (case when ips.page_count >= 1000 then 'Yes' else 'No' end) = 'Yes'
--and (case when sp.modification_counter > 0 then 'Yes' else 'No' end) = 'Yes'
--and (case when sp.modification_counter >= SQRT(ps.row_count * 1000) then 'Yes' else 'No' end) = 'Yes'
--and avg_fragmentation_in_percent >= @FragmentationLevel1
--order by TotalPages DESC;
OPTION (RECOMPILE);



/*
--	Normal for Observation
USE DBA
go
select	@@serverName as ServerName,
		db_name(ips.database_id) as DataBaseName,
		sch.name + '.' + object_name(ips.object_id) as TableName,
		ind.name as IndexName,
		ips.index_type_desc,
		ips.alloc_unit_type_desc,
		ODefrag.UpdatedTime as OlaIndexDefrag,
		avg_fragmentation_in_percent as avg_fragmentation,
		avg_page_space_used_in_percent,
		page_count,
		ps.row_count		
		--,sts.name as StatsName
		,sp.last_updated as stats_last_updated
		,sp.rows as stats_rows
		,sp.modification_counter as stats_modification_counter
		,STATS_DATE(ind.object_id, ind.index_id) AS StatsUpdated
		,OSts.UpdatedTime AS OlaStatsUpdated
		,[DeFrag_Filter = {PageCount >= 1000}] = case when ips.page_count >= 1000 then 'Yes' else 'No' end
		,[Stats_Filter = {ModifiedStatistics}] = case when sp.modification_counter > 0 then 'Yes' else 'No' end
		,[Stats_Filter = {@StatisticsModificationLevel}] = case when SQRT(ps.row_count * 1000) <= sp.modification_counter then 'Yes' else 'No' end
from sys.dm_db_index_physical_stats(DB_ID(),NULL,NULL,NULL,'LIMITED') as ips
inner join sys.indexes as ind on ips.index_id = ind.index_id and ips.object_id = ind.object_id
inner join sys.tables as tbl on ips.object_id = tbl.object_id
inner join sys.schemas as sch on tbl.schema_id = sch.schema_id
inner join sys.dm_db_partition_stats as ps on ps.object_id = ips.object_id and ps.index_id = ips.index_id
left join sys.stats as sts on sts.object_id = ind.object_id
cross apply sys.dm_db_stats_properties(ind.object_id, sts.stats_id) as sp
outer apply (SELECT MAX(cl.EndTime) as UpdatedTime FROM DBA..CommandLog as cl WHERE cl.DatabaseName = DB_NAME() and tbl.name = cl.ObjectName and sch.name = cl.SchemaName and ind.name = cl.IndexName AND cl.CommandType = 'UPDATE_STATISTICS') AS OSts
outer apply (SELECT MAX(cl.EndTime) as UpdatedTime FROM DBA..CommandLog as cl WHERE cl.DatabaseName = DB_NAME() and tbl.name = cl.ObjectName and sch.name = cl.SchemaName and ind.name = cl.IndexName AND cl.CommandType = 'ALTER_INDEX') AS ODefrag
where sts.name = ind.name
and (case when ips.page_count >= 1000 then 'Yes' else 'No' end) = 'Yes'
and (case when sp.modification_counter > 0 then 'Yes' else 'No' end) = 'Yes'
and (case when sp.modification_counter >= SQRT(ps.row_count * 1000) then 'Yes' else 'No' end) = 'Yes'
order by avg_fragmentation DESC

*/