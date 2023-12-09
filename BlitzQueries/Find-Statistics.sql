use [master]
go
declare @table_name varchar(255) = '[StackOverflow].[dbo].[Posts]'
declare @sql nvarchar(max);

declare @database_name nvarchar(255);
select @database_name = (case when len(@table_name)-len(replace(@table_name,'.','')) >= 2 then left(@table_name,CHARINDEX('.',@table_name)-1) else DB_NAME() end);
set quoted_identifier off;
set @sql = "
use "+@database_name+";
;WITH StatsOnTable AS (
	SELECT	sp.stats_id, st.name as stats_name, filter_definition, last_updated, rows, rows_sampled, steps, unfiltered_rows, 
			modification_counter, [stats_columns], [object_id] = st.object_id,
			[leading_stats_col] = case when charindex(',',c.stats_columns) > 0 
									then left(c.stats_columns,charindex(',',c.stats_columns)-1)
									else c.stats_columns end
	FROM sys.stats AS st
		 CROSS APPLY sys.dm_db_stats_properties(st.object_id, st.stats_id) AS sp
		 OUTER APPLY (	SELECT STUFF((SELECT  ', ' + c.name
						FROM  sys.stats_columns as sc
							left join sys.columns as c on sc.object_id = c.object_id AND c.column_id = sc.column_id  
						WHERE sc.object_id = st.object_id and sc.stats_id = st.stats_id
						ORDER BY sc.stats_column_id
						FOR XML PATH('')), 1, 1, '') AS [stats_columns]            
			) c
	WHERE st.object_id = OBJECT_ID(@table_name)
)
SELECT stats_id, Stats_Name, filter_definition, last_updated, rows, rows_sampled, steps, unfiltered_rows, modification_counter,
		[stats_columns], 
		[!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ tsql-Histogram ~~~~~~~~~~~~~~~~~~~~~~~~~~!] = 'USE "+@database_name+"; select stats_col = '''+ltrim(rtrim([leading_stats_col]))+''', * from '+QUOTENAME(DB_NAME())+'.sys.dm_db_stats_histogram ('+convert(varchar,[object_id])+', '+convert(varchar,stats_id)+') h;'
		,[--tsql-SHOW_STATISTICS--] = 'dbcc show_statistics ('''+@table_name+''','+stats_name+')'
FROM StatsOnTable sts ORDER BY [stats_columns];
"
set quoted_identifier off;
--print @sql
exec sp_ExecuteSql @sql, N'@table_name varchar(255), @database_name nvarchar(255)', @table_name, @database_name;

--exec sp_BlitzIndex @DatabaseName = 'StackOverflow', @SchemaName = 'dbo', @TableName = 'Posts'

-- dbcc show_statistics ('dbo.Posts',_WA_Sys_0000000B_39D87308)

