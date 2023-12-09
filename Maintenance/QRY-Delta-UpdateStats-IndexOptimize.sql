use DBA
go

set transaction isolation level read uncommitted;
set nocount on;
--set quoted_identifier off;
set lock_timeout 60000; -- 60 seconds

declare @execute_indexoptimize bit = 1
declare @p_db_name sysname 
--set @p_db_name = 'StackOverflow'

if object_id('tempdb..#stats') is not null
	drop table #stats;
create table #stats
(	id bigint identity(1,1) not null, [db_name] sysname, table_name nvarchar(500), stats_id bigint, stats_name sysname,
	last_updated datetime2, rows_total bigint, rows_sampled bigint, steps int, unfiltered_rows bigint,
	modification_count bigint, sqrt_formula bigint, [threshold %] numeric(20,2), order_id numeric(20,2)
);

declare @query_get_stats nvarchar(max)
set @query_get_stats = '
use [?];
if (len('''+ISNULL(@p_db_name,'')+''') = 0 or (DB_NAME() = '''+ISNULL(@p_db_name,'')+''') ) and (DB_NAME() NOT IN (''DBA''))
begin
	--print ''executing for [''+db_name()+'']'';
	;with tStats as (
	select	db_name() as DbName, QUOTENAME(schema_name(o.schema_id))+''.''+QUOTENAME(o.name) as ObjectName, sp.stats_id, st.name, sp.last_updated, ps.rows_total,
			sp.rows_sampled, sp.steps, sp.unfiltered_rows, sp.modification_counter
			,(SELECT CONVERT(decimal(20,0),MIN (val)) FROM (VALUES (500 + (0.20 * ps.rows_total)),(SQRT(1000 * ps.rows_total))) as Thresholds(val)) as SqrtFormula
			--,(case when sp.modification_counter >= (SELECT CONVERT(decimal(20,0),MIN (val)) FROM (VALUES (500 + (0.20 * ps.rows_total)),(SQRT(1000 * ps.rows_total))) as Thresholds(val)) then 1 else 0 end) as _Ola_IndexOptimize
	from sys.stats as st
	cross apply sys.dm_db_stats_properties(st.object_id, st.stats_id) as sp
	join sys.objects o on o.object_id = st.object_id
	outer apply (SELECT SUM(ps.row_count) AS rows_total
							FROM sys.dm_db_partition_stats as ps WHERE ps.object_id = st.object_id AND ps.index_id < 2
							GROUP BY ps.object_id
	) as ps
	where ps.rows_total >= 50000
	and (NOT ( o.name like ''!_td!_bl%'' escape ''!'' or o.name like ''%audit%''))
	and (	--sp.modification_counter >= 10000 or
			(case when sp.modification_counter >= (SELECT CONVERT(decimal(20,0),MIN (val)) FROM (VALUES (500 + (0.20 * ps.rows_total)),(SQRT(1000 * ps.rows_total))) as Thresholds(val)) then 1 else 0 end) = 1
		)
	and ( (case when o.is_ms_shipped = 1 and ps.rows_total >= 100000 then 1 when o.is_ms_shipped = 0 then 1 else 0 end) = 1 )
	)
	select *, convert(decimal(20,0),(modification_counter*100)/SqrtFormula) as [threshold %]
			,(SQRT(s.rows_total)*0.3) +(convert(decimal(20,0),(modification_counter*100)/SqrtFormula)) as order_id
	from tStats s
	where SqrtFormula > 0
	order by order_id
end
'
print @query_get_stats

insert #stats
exec sp_MSforeachdb @query_get_stats

select	db_name, table_name, COUNT(*) as stats_count_total,
		max(last_updated) as last_updated, max(rows_total) as rows_total, max(modification_count) as modification_count
		,QUOTENAME(db_name)+'.'+table_name as [@Indexes]
		,[********************* tsql-RECOMPILE ***********************] = 'exec '+QUOTENAME(s.db_name)+'..sp_recompile '''+table_name+''''
from #stats s
group by db_name, table_name
order by max(order_id) desc;

if(@execute_indexoptimize = 1)
begin
	declare @db_name sysname, @indexes nvarchar(500);
	declare cur_stats cursor local forward_only for
			select db_name, db_name+'.'+table_name as [@Indexes]
			from #stats
			where (db_name = @p_db_name or @p_db_name is null)
			and db_name <> 'tempdb'
			group by db_name, table_name
			order by max(order_id) desc;

	open cur_stats;
	fetch next from cur_stats into @db_name, @indexes;

	while @@FETCH_STATUS = 0
	begin
		begin try
			EXECUTE dbo.IndexOptimize
									@Databases = @db_name,
									--@Databases = 'AVAILABILITY_GROUP_DATABASES',
									@FragmentationLow = NULL,
									@FragmentationMedium = NULL,
									@FragmentationHigh = NULL,
									@UpdateStatistics = 'ALL',
									@OnlyModifiedStatistics = 'Y',
									--@StatisticsSample = 100,
									@PartitionLevel = 'Y',
									@LogToTable = 'N',
									@SortInTempdb = 'Y',
									@MSShippedObjects = 'Y',
									--@MaxDOP = 4,
									/* Run parallel update stats for each table */
									@Indexes = @indexes
									,@Execute = 'Y';
		end try
		begin catch
			print '*************************************************************************************'
			print '*************************************************************************************'
			print '@db_name = '+quotename(@db_name);
			print '@Indexes = '''+@indexes+'''';
			print ERROR_MESSAGE();
			print '*************************************************************************************'
			print '*************************************************************************************'
		end catch

		fetch next from cur_stats into @db_name, @indexes;
	end
	CLOSE cur_stats;
	DEALLOCATE cur_stats;
end
go


/*
EXECUTE dbo.IndexOptimize
		@Databases = 'ALL_DATABASES',
		--@Databases = 'AVAILABILITY_GROUP_DATABASES',
		@FragmentationLow = NULL,
		@FragmentationMedium = NULL,
		@FragmentationHigh = NULL,
		@UpdateStatistics = 'ALL',
		@OnlyModifiedStatistics = 'Y',
		--@StatisticsSample = 100,
		@PartitionLevel = 'Y',
		@LogToTable = 'N',
		@SortInTempdb = 'Y',
		@MSShippedObjects = 'Y'
		--@MaxDOP = 4,
		/* Run parallel update stats for each table */
		--@Indexes = @indexes
		,@Execute = 'Y';
*/

/*
Install-DbaMaintenanceSolution -SqlInstance '192.168.100.196' -Database 'DBA' -SqlCredential $personal -Force -ReplaceExisting
*/