set nocount on;

declare @max_identity_by_row bigint = -1;
declare @current_identity_value bigint = -1;
declare @c_table_name varchar(500);
declare @c_identity_col_name varchar(200);
declare @t_identity_checks table (
	[result] varchar(500), [table_name] varchar(500), [current_identity_value] bigint, 
	[max_identity_by_row] bigint, [tsql_to_reseed_identity] nvarchar(max), [is_reseed_needed] bit
);

declare @_sql nvarchar(max);
declare cur_tables cursor local forward_only for
	select table_name = s.name+'.'+o.name, column_name = c.name
	from sys.columns c
	join sys.objects o on o.object_id = c.object_id
	join sys.schemas s on o.schema_id = s.schema_id
	where 1=1
	and o.name in (<<table_names_without_schemas>>)
	--and o.name in ('Users','Posts','Badges')
	and c.is_identity = 1;

open cur_tables;
fetch next from cur_tables into @c_table_name, @c_identity_col_name;
while @@FETCH_STATUS = 0
begin
	print @c_table_name

	set @current_identity_value = IDENT_CURRENT(@c_table_name);
	set @_sql = N'select @max_identity_by_row = max('+@c_identity_col_name+') from '+@c_table_name+' t';
	exec sp_executesql @_sql, N'@max_identity_by_row bigint OUTPUT', @max_identity_by_row output;

	if @current_identity_value < @max_identity_by_row
	begin
		set @_sql = N'DBCC CHECKIDENT ('''+@c_table_name+''', RESEED, '+CONVERT(varchar,@max_identity_by_row)+');';

		insert @t_identity_checks 
		([result], [table_name], [current_identity_value], [max_identity_by_row], [tsql_to_reseed_identity], [is_reseed_needed])
		select  [result] = 'ERROR: Identity lower than max value in table', 
				[table_name] = @c_table_name,
				[current_identity_value] = @current_identity_value, 
				[max_identity_by_row] = @max_identity_by_row,
				[tsql_to_reseed_identity] = @_sql,
				[is_reseed_needed] = cast(1 as bit);
	end
	else
		insert @t_identity_checks 
		([result], [table_name], [current_identity_value], [max_identity_by_row], [tsql_to_reseed_identity], [is_reseed_needed])
		select  [result] = 'SUCCESS: No issue found.', 
				[table_name] = @c_table_name,
				[current_identity_value] = @current_identity_value, 
				[max_identity_by_row] = @max_identity_by_row,
				[tsql_to_reseed_identity] = null,
				[is_reseed_needed] = cast(0 as bit);

	fetch next from cur_tables into @c_table_name, @c_identity_col_name;
end

select	server_name = '<server_name>', [database_name] = DB_NAME(),
		[result] = coalesce(ic.[result], d.[result]),
		[table_name] = coalesce(ic.table_name,d.table_name), 
		[current_identity_value] = coalesce(ic.current_identity_value, d.current_identity_value), 
		[max_identity_by_row] = coalesce(ic.max_identity_by_row, d.max_identity_by_row), 
		[tsql_to_reseed_identity] = coalesce(ic.tsql_to_reseed_identity, d.tsql_to_reseed_identity), 
		[is_reseed_needed] = coalesce(ic.is_reseed_needed,d.is_reseed_needed)
from @t_identity_checks ic
full outer join (
	select	[result] = 'SUCCESS: No identity columns found.',
			[table_name] = convert(varchar(500),null),
			[current_identity_value] = convert(bigint, null),
			[max_identity_by_row] = convert(bigint,null),
			[tsql_to_reseed_identity] = convert(nvarchar(max),null),
			[is_reseed_needed] = convert(bit,0)
	) d on 1=1
