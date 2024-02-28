use <<DatabaseWhereUpdateStatsIsNeeded>>

declare @table_name varchar(125) = 'dbo.Posts';
;with tStats as (
	select	db_name() as [db_name], schema_name(o.schema_id)+'.'+o.name as [object_name], st.object_id, sp.stats_id, st.name as stats_name, st.auto_created, sp.last_updated, ps.rows_total,
			sp.rows_sampled, sp.steps, sp.unfiltered_rows, sp.modification_counter
			,(SELECT CONVERT(decimal(20,0),MIN (val)) FROM (VALUES (500 + (0.20 * ps.rows_total)),(SQRT(1000 * ps.rows_total))) as Thresholds(val)) as [UpdateThreshold]
			--,(case when sp.modification_counter >= (SELECT CONVERT(decimal(20,0),MIN (val)) FROM (VALUES (500 + (0.20 * ps.rows_total)),(SQRT(1000 * ps.rows_total))) as Thresholds(val)) then 1 else 0 end) as _Ola_IndexOptimize
	from sys.stats as st
	cross apply sys.dm_db_stats_properties(st.object_id, st.stats_id) as sp
	join sys.objects o on o.object_id = st.object_id
	outer apply (SELECT SUM(ps.row_count) AS rows_total
							FROM sys.dm_db_partition_stats as ps WHERE ps.object_id = st.object_id AND ps.index_id < 2
							GROUP BY ps.object_id
	) as ps
	where o.is_ms_shipped = 0
	and o.object_id = OBJECT_ID(@table_name)
)
,t_stats_final as (
	select	[db_name], [object_name], stats_name,
			[columns] = STUFF((SELECT ', ' + c.name --convert(varchar,sc.column_id)
								from sys.stats_columns as sc
								join sys.columns c on c.object_id = sc.object_id and c.column_id = sc.column_id
								where sc.object_id = s.object_id and sc.stats_id = s.stats_id
								ORDER BY sc.stats_column_id
								FOR XML PATH('')
							), 1, 1, ''),
			[current_time] = GETDATE(), [last_updated], auto_created, [rows_total], [rows_sampled], [steps],
			[unfiltered_rows], [modification_counter], [UpdateThreshold]
			,[threshold %] = case when [UpdateThreshold] = 0 then null else convert(decimal(20,0),(modification_counter*100)/[UpdateThreshold]) end
			--,[order_id] = (SQRT(s.rows_total)*0.3) +(convert(decimal(20,0),(modification_counter*100)/[UpdateThreshold]))
	from tStats s
	--where s.[object_name] = @table_name
)
select	*
		,[--tsql--] = case when modification_counter > [UpdateThreshold] then 'update statistics '+quotename(db_name())+'.'+@table_name+' '+stats_name+' with sample 5 percent, maxdop=0;' else null end
from t_stats_final
--order by 1,2,4,3,[threshold %] desc
go



--DBCC SHOW_STATISTICS ('dbo.who_is_active','pk_who_is_active');

/*
OPTION (	RECOMPILE
			,QUERYTRACEON 9481 /* Old CE */
			--QUERYTRACEON 2312 /* New CE */
			--USE HINT('QUERY_OPTIMIZER_COMPATIBILITY_LEVEL_150','FORCE_DEFAULT_CARDINALITY_ESTIMATION')
			,QUERYTRACEON 9204 /* Get loaded stats */
			,QUERYTRACEON 3604 /* Output stats to msg tab */
		)
*/