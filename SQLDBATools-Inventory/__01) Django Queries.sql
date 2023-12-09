-- Server
SET NOCOUNT ON;
declare @objectName varchar(50) = 'server';

Declare @columns varchar(max);

select	@columns = case when column_id%4=0 then coalesce(@columns + ', ' + CHAR(13) + name, name)
						else coalesce(@columns + ', ' + name, name)
						end
from  sys.columns c WHERE OBJECT_NAME(c.object_id) = @objectName
order by c.column_id asc

print @columns
print '**************************************************************'
print '**************************************************************'
print '**************************************************************'
go


SET NOCOUNT ON;
declare @objectName varchar(50) = 'server';
Declare @columns varchar(max)
		,@selectQuery varchar(max)
		,@tableAlias char(2)
		,@joins varchar(max)

set @tableAlias = 't'+left(@objectName,2);

if OBJECT_ID('tempdb..#t_fk') is not null
	drop table #t_fk;
select	bc.name as bc_name, bc.column_id, OBJECT_NAME(fkc.referenced_object_id) as rc_table, rc.name as rc_name, 't'+left(rc.name,2) as rc_alias
		,[join_clause] = '
left join '+OBJECT_NAME(fkc.referenced_object_id)+' as t'+left(rc.name,2)+ ' on '+@tableAlias+'.'+bc.name+' = '+'t'+left(rc.name,2)+'.'+rc.name
into #t_fk
from sys.foreign_key_columns as fkc --on fkc.parent_object_id = fk.parent_object_id and fkc.constraint_object_id = fk.object_id
	join sys.columns as bc on fkc.parent_object_id = bc.object_id and fkc.parent_column_id = bc.column_id
	join sys.columns as rc on fkc.referenced_object_id = rc.object_id and fkc.referenced_column_id = rc.column_id
where object_name(fkc.parent_object_id) = @objectName;

--select * from #t_fk

;with t_cols as
(
	select [col_name] = case	when fk.bc_name is not null then fk.rc_alias+'.'+rc_name
								else @tableAlias+'.'+c.name
								end
			,c.column_id
	from  sys.columns as c left join #t_fk as fk on fk.bc_name = c.name
	WHERE OBJECT_NAME(c.object_id) = @objectName
)
select @columns = case when column_id%4=0 then coalesce(@columns + ', ' + CHAR(13) + [col_name], [col_name])
						else coalesce(@columns + ', ' + [col_name], [col_name])
						end
from  t_cols
order by column_id asc;

set @selectQuery = 'select '+@columns+'
from '+ @objectName + ' as '+@tableAlias;

select @joins = coalesce(@joins + [join_clause], [join_clause])
from #t_fk;

set @selectQuery += @joins;

print @selectQuery

--select * from sys.foreign_key_columns
