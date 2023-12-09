use tempdb
EXEC master.dbo.sp_BlitzIndex @getalldatabases = 1, @BringThePain = 1
EXEC master.dbo.sp_BlitzIndex @GetAllDatabases = 1, @Mode = 1 -- summarize database metrics
EXEC master.dbo.sp_BlitzIndex @GetAllDatabases = 1, @Mode = 2 -- index usage details

EXEC master..sp_BlitzIndex @DatabaseName = 'RDP' ,@BringThePain = 1 -- Bring only main issues

EXEC master..sp_BlitzIndex @DatabaseName = 'StackOverflow', @SchemaName = 'dbo', @TableName = 'Posts'
go

/*	Store index Details into Table, and Analyze them one by one */
declare @database_name varchar(200) = 'StackOverflow'
declare @table_name varchar(200) = 'Posts'

declare @sql nvarchar(max);
set @sql = '
select [index_name] = i.database_name+''.''+i.schema_name+''.''+i.table_name+''.''+i.index_name, i.index_definition, i.index_size_summary,
		i.index_usage_summary, i.index_op_stats, i.data_compression_desc, i.fill_factor, i.create_date
		--,i.*
from tempdb..BlitzIndexOutput i
where i.database_name = @p_database_name
and i.table_name = @p_table_name
order by case when index_id <= 1 then ''1'' else i.key_column_names_with_sort_order end '
exec sp_executesql @sql, N'@p_database_name varchar(200), @p_table_name varchar(200)'
					,@p_database_name=@database_name, @p_table_name=@table_name;

exec sp_BlitzIndex @DatabaseName = @database_name, @TableName = @table_name


/*
exec sp_BlitzIndex @GetAllDatabases = 1, @Mode = 2, @BringThePain = 1
					,@OutputDatabaseName = 'tempdb', @OutputSchemaName = 'dbo', @OutputTableName = 'BlitzIndexOutput'
go
*/

--select top 10 * from tempdb..BlitzIndexOutput i