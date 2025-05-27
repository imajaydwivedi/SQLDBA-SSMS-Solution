use DBA
go

set transaction isolation level read uncommitted;
set nocount on;
--set quoted_identifier off;
set lock_timeout 60000; -- 60 seconds

declare @p_execute_indexoptimize bit = 1;
declare @p_generate_updatestats_stmts bit = 1;
declare @p_execute_generated_updatestats_stmts bit = 1;
declare @p_db_name sysname --= 'StackOverflow';
declare @p_min_record_count bigint = 1000;
declare @p_add_batch_separator bit = 0;

if object_id('tempdb..#stats') is not null
	drop table #stats;
create table #stats
(	id bigint identity(1,1) not null, [db_name] sysname, table_name nvarchar(500), stats_id bigint, stats_name sysname,
	last_updated datetime2, rows_total bigint, no_recompute smallint, rows_sampled bigint, steps int, unfiltered_rows bigint,
	modification_count bigint, [object_id] int, sqrt_formula bigint, [stats_columns] varchar(2000), leading_stats_col varchar(255), 
	[threshold %] numeric(20,2), order_id numeric(20,2)
);

print 'Loop through DBs to fetch Stats info';

declare @c_db_name varchar(255);
declare @_params nvarchar(max);
declare @_sql nvarchar(max);
declare @_sql_temp nvarchar(max);

set @_params = N'@min_record_count bigint';
set @_sql = N'
;with tStats as (
	select	db_name() as DbName, QUOTENAME(schema_name(o.schema_id))+''.''+QUOTENAME(o.name) as ObjectName, sp.stats_id, 
			st.name, sp.last_updated, ps.rows_total, no_recompute, sp.rows_sampled, sp.steps, sp.unfiltered_rows, 
			sp.modification_counter, st.object_id
			,(SELECT CONVERT(decimal(20,0),MIN (val)) FROM (VALUES (500 + (0.20 * ps.rows_total)),(SQRT(1000 * ps.rows_total))) as Thresholds(val)) as SqrtFormula
			,[stats_columns] = LTRIM(RTRIM([stats_columns]))
			,[leading_stats_col] = case when charindex('','',c.stats_columns) > 0 
										then left(c.stats_columns,charindex('','',c.stats_columns)-1)
										else c.stats_columns end
			--,(case when sp.modification_counter >= (SELECT CONVERT(decimal(20,0),MIN (val)) FROM (VALUES (500 + (0.20 * ps.rows_total)),(SQRT(1000 * ps.rows_total))) as Thresholds(val)) then 1 else 0 end) as _Ola_IndexOptimize
	from sys.stats as st
	cross apply sys.dm_db_stats_properties(st.object_id, st.stats_id) as sp
	join sys.objects o on o.object_id = st.object_id
	outer apply (SELECT SUM(ps.row_count) AS rows_total
							FROM sys.dm_db_partition_stats as ps WHERE ps.object_id = st.object_id AND ps.index_id < 2
							GROUP BY ps.object_id
	) as ps
	outer apply ( SELECT STUFF((SELECT  '', '' + c.name
				FROM  sys.stats_columns as sc
					left join sys.columns as c on sc.object_id = c.object_id AND c.column_id = sc.column_id  
				WHERE sc.object_id = st.object_id and sc.stats_id = st.stats_id
				ORDER BY sc.stats_column_id
				FOR XML PATH('''')), 1, 1, '''') AS [stats_columns]            
			) c
	where ps.rows_total >= @min_record_count
	and (NOT ( o.name like ''!_td!_bl%'' escape ''!'' or o.name like ''%audit%''))
	and (	(case when sp.modification_counter >= (SELECT CONVERT(decimal(20,0),MIN (val)) FROM (VALUES (500 + (0.20 * ps.rows_total)),(SQRT(1000 * ps.rows_total))) as Thresholds(val)) then 1 else 0 end) = 1
		)
	and ( (case when o.is_ms_shipped = 1 and ps.rows_total >= @min_record_count then 1 when o.is_ms_shipped = 0 then 1 else 0 end) = 1 )
)
select *, convert(decimal(20,0),(modification_counter*100)/SqrtFormula) as [threshold %]
		,[order_id] = (SQRT(s.rows_total)*0.3) +(convert(decimal(20,0),(modification_counter*100)/SqrtFormula))
from tStats s
where SqrtFormula > 0
order by order_id;'
--print @_sql

declare cur_dbs cursor local forward_only for
	select name --,d.is_read_only, d.is_in_standby, d.state_desc, *
	from sys.databases d
	where 1=1
	and (case when d.is_read_only = 1 then 0
				when d.is_in_standby = 1 then 0
				when d.state_desc in ('ONLINE') then 1
				else 0
				end) = 1
	and (name = @p_db_name or @p_db_name is null)
	and name <> 'tempdb';

open cur_dbs;
fetch next from cur_dbs into @c_db_name;

while @@FETCH_STATUS = 0
begin
	set @_sql_temp = 'use '+QUOTENAME(@c_db_name)+';'+char(13)+@_sql;
	begin try
		insert #stats
		exec sp_executesql @_sql_temp, @_params, @min_record_count=@p_min_record_count;
	end try
	begin catch
		print char(9)+'Failure during stats collection for database '+QUOTENAME(@c_db_name);
		print '*************************************************************************************'
		print '*************************************************************************************'
		print '@c_db_name = '+quotename(@c_db_name);
		print ERROR_MESSAGE();
		print '*************************************************************************************'
		print '*************************************************************************************'
	end catch

	fetch next from cur_dbs into @c_db_name;
end
CLOSE cur_dbs;
DEALLOCATE cur_dbs;

if(@p_execute_generated_updatestats_stmts=0)
begin
	print 'Display table level aggregated stats info';
	select	row_id = ROW_NUMBER()over(order by max(order_id) desc), db_name, table_name, COUNT(*) as stats_count_total,
			max(last_updated) as last_updated, max(rows_total) as rows_total, max(modification_count) as modification_count
			,QUOTENAME(db_name)+'.'+table_name as [@Indexes]
			,no_recompute = sum(no_recompute)
			,[********************* tsql-RECOMPILE ***********************] = 'exec '+QUOTENAME(s.db_name)+'..sp_recompile '''+table_name+''''
	from #stats s
	group by db_name, table_name
	order by max(order_id) desc;
end
else
begin
	print 'Display stats info';
	--select * from #stats
	select	row_id = ROW_NUMBER()over(order by order_id desc), 
			[db_name], table_name, stats_id, stats_name, leading_stats_col, last_updated, rows_total, no_recompute,
			rows_sampled, steps, unfiltered_rows, modification_count, sqrt_formula, [threshold %],
			[@_sample_percent] = case	when rows_total >= 1000000000 then 2 -- > 1 billion
									when rows_total >= 10000000 then 5 -- > 10 million
									when rows_total >= 1000000 then 20 -- > 1 million
									when rows_total >= 100000 then 10 -- 100k
									else 100
									end,
			[!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ tsql-Histogram ~~~~~~~~~~~~~~~~~~~~~~~~~~!] = 'USE ['+st.[db_name]+']; select stats_col = '''+ltrim(rtrim([leading_stats_col]))+''', * from '+QUOTENAME(st.[db_name])+'.sys.dm_db_stats_histogram ('+convert(varchar,[object_id])+', '+convert(varchar,stats_id)+') h;'
			,[--tsql-SHOW_STATISTICS--] = 'USE ['+st.[db_name]+']; dbcc show_statistics ('''+(table_name collate SQL_Latin1_General_CP1_CI_AS)+''','+stats_name+')'
	from #stats st
	where 1=1
	order by row_id;
end

declare @c_indexes nvarchar(500);
declare @c_id int;
declare @c_table_name varchar(1000);
declare @c_stats_name varchar(500);
declare @c_last_updated datetime2;
declare @c_rows_total bigint;
declare @c_rows_sampled bigint;
declare @c_steps smallint;
declare @c_modification_count bigint;
declare @c_sqrt_formula bigint;
declare @_sample_percent int;

if (@p_generate_updatestats_stmts=1)
begin
	print 'Loop through each stats, and generate 5% sample update stats query';
	print '--'+replicate ('**',40)

	declare cur_stats cursor local forward_only for
			select id = ROW_NUMBER()over(order by order_id desc), [db_name], [table_name], stats_name,
					last_updated, rows_total, rows_sampled, steps, modification_count, sqrt_formula
			from #stats st
			where 1=1
			order by order_id desc;

	open cur_stats;
	fetch next from cur_stats into @c_id, @c_db_name, @c_table_name, @c_stats_name, @c_last_updated, @c_rows_total,
									@c_rows_sampled, @c_steps, @c_modification_count, @c_sqrt_formula;

	while @@FETCH_STATUS = 0
	begin
		set @_sample_percent = case	when @c_rows_total >= 1000000000 then 2 -- > 1 billion
									when @c_rows_total >= 10000000 then 5 -- > 10 million
									when @c_rows_total >= 1000000 then 20 -- > 1 million
									when @c_rows_total >= 100000 then 10 -- 100k
									else 100
									end
		--print char(9)+'Looping through '+QUOTENAME(@c_db_name);
		set @_sql_temp = 'update /* '+convert(varchar,@c_id)+' */ statistics '+quotename(@c_db_name)+'.'+@c_table_name+' '+
							quotename(@c_stats_name)+' with sample '+convert(varchar,@_sample_percent)+' percent, maxdop=0;'+
							(case when @p_add_batch_separator=1 then char(13)+'go' else '' end);

		print @_sql_temp;
		if(@p_execute_generated_updatestats_stmts=1)
		begin
			begin try
				exec (@_sql_temp);
			end try
			begin catch
				print '*************************************************************************************'
				print '*************************************************************************************'
				print '@c_db_name = '+quotename(@c_db_name);
				print '@c_table_name = '''+@c_table_name+'''';
				print '@c_stats_name = '''+@c_stats_name+'''';
				print ERROR_MESSAGE();
				print '*************************************************************************************'
				print '*************************************************************************************'
			end catch
		end
		fetch next from cur_stats into @c_id, @c_db_name, @c_table_name, @c_stats_name, @c_last_updated, @c_rows_total,
									@c_rows_sampled, @c_steps, @c_modification_count, @c_sqrt_formula;
	end
	CLOSE cur_stats;
	DEALLOCATE cur_stats;

	print '--'+replicate ('**',40)
end

if @p_execute_generated_updatestats_stmts = 1
begin
	print 'Since @p_execute_generated_updatestats_stmts is enabled, then set @p_execute_indexoptimize to off.';
	set @p_execute_indexoptimize = 0;
end

if(@p_execute_indexoptimize = 1)
begin
	print 'Using Ola IndexOptimize, update Modified Statistics';

	declare cur_tables cursor local forward_only for
			select id = ROW_NUMBER()over(order by max(order_id) desc), db_name, db_name+'.'+table_name as [@Indexes]
			from #stats
			where (db_name = @p_db_name or @p_db_name is null)
			and db_name <> 'tempdb'
			group by db_name, table_name
			order by max(order_id) desc;

	open cur_tables;
	fetch next from cur_tables into @c_id, @c_db_name, @c_indexes;

	while @@FETCH_STATUS = 0
	begin
		print char(13)+'************************* Working on "'+convert(varchar,@c_id)+'"..'+char(13);
		begin try
			EXECUTE dbo.IndexOptimize
									@Databases = @c_db_name,
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
									@Indexes = @c_indexes
									,@Execute = 'Y';
		end try
		begin catch
			print '*************************************************************************************'
			print '*************************************************************************************'
			print '@c_db_name = '+quotename(@c_db_name);
			print '@c_indexes = '''+@c_indexes+'''';
			print ERROR_MESSAGE();
			print '*************************************************************************************'
			print '*************************************************************************************'
		end catch

		fetch next from cur_tables into @c_id, @c_db_name, @c_indexes;
	end
	CLOSE cur_tables;
	DEALLOCATE cur_tables;
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