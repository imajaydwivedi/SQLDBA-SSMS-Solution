use db1;
go

declare @table_count int = 20;
;with cte_tables as ( select rowno = 1 union all select rowno = rowno+1 from cte_tables where rowno < @table_count )
select	table_name = 'target_table_'+convert(varchar(20),rowno),
		tsql_create_table = 'if object_id(''dbo.'+t.table_name+''') is null create table '+t.table_name+' (col1 uniqueidentifier);',
		tsql_truncate_table = 'if object_id(''dbo.'+t.table_name+''') is not null truncate table '+t.table_name+';',
		tsql_insert_table = 'INSERT INTO '+t.table_name+' (col1) SELECT TOP 10000000 NEWID() FROM sys.all_columns a CROSS JOIN sys.all_columns b;',
		tsql_drop_table = 'if object_id(''dbo.'+t.table_name+''') is not null drop table '+t.table_name+';',
		cmd_parallel_load = 'start "'+t.table_name+'" sqlcmd -S localhost -d db1 -C -Q "INSERT INTO '+t.table_name+' (col1) SELECT TOP 10000000 NEWID() FROM sys.all_columns a CROSS JOIN sys.all_columns b;"'
from cte_tables c outer apply (select table_name = 'target_table_'+convert(varchar(20),rowno)) t
go


