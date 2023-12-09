USE DBA;
declare @database_name varchar(200),
		@table_name varchar(200);
set @database_name = 'StackOverflow';
set @table_name = 'Posts'

declare @sql nvarchar(max);
set nocount on;
-- Summary
set @sql = '
with cte_data as (
	select	i.*, 
			[db_position_start] = CHARINDEX(''@DatabaseName='',more_info)+len(''@DatabaseName='')+1,
			[db_position_end] = CHARINDEX(''@SchemaName='',more_info)-3-(CHARINDEX(''@DatabaseName='',more_info)+len(''@DatabaseName='')+1),
			[schema_position_start] = CHARINDEX(''@SchemaName='',more_info)+len(''@SchemaName='')+1,
			[schema_position_end] = CHARINDEX(''@TableName='',more_info)-3-(CHARINDEX(''@SchemaName='',more_info)+len(''@SchemaName='')+1),
			[table_position_start] = CHARINDEX(''@TableName='',more_info)+len(''@TableName='')+1,
			[table_position_end] = LEN(more_info)-1,
			[benefits_length] = len(i.details)-charindex(''Est. benefit per day'',i.details)
	from dbo.BlitzIndex_Summary_Aug26 i
)
select	--top 20 
		[*Query*] = ''Summary'', i.finding, i.database_name, 
		[table_name] = QUOTENAME(i.database_name)+''.''+QUOTENAME(substring(more_info,[schema_position_start],[schema_position_end]))+''.''+QUOTENAME(substring(more_info,[table_position_start],[table_position_end]-[table_position_start])),
		benefits_length,
		[details] = case when finding like ''Indexaphobia%'' then right(i.details,[benefits_length]+1) else i.details end,
		i.definition, i.secret_columns, i.usage, i.size, i.create_tsql, i.more_info
from cte_data i
where 1 = 1
and i.finding like ''Indexaphobia%''
and ( @p_database_name is null or i.database_name = @p_database_name )
and ( @p_table_name is null or (substring(more_info,[table_position_start],[table_position_end]-[table_position_start])) = @p_table_name )
order by finding, table_name, priority
'
exec sp_executesql @sql, N'@p_database_name varchar(200), @p_table_name varchar(200)'
					,@p_database_name=@database_name, @p_table_name=@table_name;

-- Detailed
set @sql = '
select	--top 20
		[*Query*] = ''Index-Details'', [index_name] = i.database_name+''.''+i.schema_name+''.''+i.object_name+''.''+i.index_name, i.definition, i.index_size,
		i.index_usage, i.index_op_stats, i.data_compression, i.fill_factor, 
		[forwarded_fetches] = case when i.forwarded_fetches > 0 then format(convert(bigint,i.forwarded_fetches),''N0'')+'' forward records fetched.'' else null end, 
		i.create_date, i.drop_tsql, i.create_tsql
		--,i.*
from dbo.BlitzIndex_Detailed_Aug26 i
where (@p_database_name is null or i.database_name = @p_database_name)
and (@p_table_name is null or i.object_name = @p_table_name)
order by case when index_id <= 1 then ''1'' else i.key_column_names_with_sort end '
exec sp_executesql @sql, N'@p_database_name varchar(200), @p_table_name varchar(200)'
					,@p_database_name=@database_name, @p_table_name=@table_name;

if @table_name is not null
exec sp_BlitzIndex @DatabaseName = @database_name, @TableName = @table_name

--select distinct finding from DBA..BlitzIndex_Summary_Aug26
--select * from DBA..BlitzIndex_Detailed_Aug26



/*	****** SAVE sp_BlitzIndex result to SQL Tables  ****************************
exec sp_BlitzIndex @GetAllDatabases = 1, @Mode = 2, @BringThePain = 1
					,@OutputDatabaseName = 'tempdb', @OutputSchemaName = 'dbo', @OutputTableName = 'BlitzIndexOutput'
go
*/

/*	****************** Rename Columns of tables ********************************
select	[rename-tsql] = 'EXEC '+TABLE_CATALOG+'..sp_rename '''+(TABLE_SCHEMA+'.'+TABLE_NAME+'.'+QUOTENAME(COLUMN_NAME))+''', '''+REPLACE(LOWER(C.COLUMN_NAME),' ','_')+''', ''COLUMN'';',
		[Space Check] = CHARINDEX(' ',C.COLUMN_NAME),
		[Case Check] = case when C.COLUMN_NAME = LOWER(C.COLUMN_NAME) COLLATE Latin1_General_CS_AS THEN 'Same Case' else 'Different Case' end,
		*
from DBA.INFORMATION_SCHEMA.COLUMNS c
where c.TABLE_NAME = 'BlitzIndex_Detailed_Aug26'
AND (	CHARINDEX(' ',C.COLUMN_NAME) > 0
		OR C.COLUMN_NAME <> LOWER(C.COLUMN_NAME) COLLATE Latin1_General_CS_AS
	);
*/

/*	****************** Get Details from sp_BlitzIndex Output for Specific Tables *******************
declare @sql nvarchar(max);
set @sql = '
select [index_name] = i.database_name+''.''+i.schema_name+''.''+i.table_name+''.''+i.index_name, i.index_definition, i.index_size_summary,
		i.index_usage_summary, i.index_op_stats, i.data_compression_desc, i.fill_factor, i.create_date
		--,i.*
from dbo.BlitzIndex_Detailed_Aug26 i
where i.database_name = @p_database_name
and i.table_name = @p_table_name
order by case when index_id <= 1 then ''1'' else i.key_column_names_with_sort_order end '
exec sp_executesql @sql, N'@p_database_name varchar(200), @p_table_name varchar(200)'
					,@p_database_name=@database_name, @p_table_name=@table_name;
*/