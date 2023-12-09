set nocount on;
set quoted_identifier on;

declare @flush_threshold_minutes int = 10;
declare @verbose bit = 1;

declare @collection_time datetime;
select @collection_time = max(collection_time) from DBA.dbo.who_is_active w;

if @verbose = 1
	select [plan_handle] = COALESCE(additional_info.value('(/additional_info/plan_handle)[1]','varchar(125)'), additional_info.value('(/additional_info/sql_handle)[1]','varchar(125)'))
			,getdate(), *
	from DBA.dbo.who_is_active w
	where w.collection_time = @collection_time
	and DATEDIFF(MINUTE,w.start_time,w.collection_time) > @flush_threshold_minutes

declare @c_plan_handle varchar(125);
declare @sql varchar(500);

declare cur_plan_handles cursor local forward_only for
	select DISTINCT [plan_handle] = COALESCE(additional_info.value('(/additional_info/plan_handle)[1]','varchar(125)'), additional_info.value('(/additional_info/sql_handle)[1]','varchar(125)'))
	from DBA.dbo.who_is_active w
	where w.collection_time = @collection_time
	and DATEDIFF(MINUTE,w.start_time,w.collection_time) > @flush_threshold_minutes;

open cur_plan_handles;
fetch next from cur_plan_handles into @c_plan_handle;

while @@FETCH_STATUS = 0
begin
	begin try
		set @sql =  'dbcc freeproccache ('+@c_plan_handle+');'
		--print 'Flushing plan/sql handle -> '+convert(varchar(125),@c_plan_handle);
		print @sql
		if @verbose = 0
			exec (@sql);		
	end try
	begin catch
		print ERROR_MESSAGE();
		print 'Error while flushing plan/sql handle -> '+convert(varchar(125),@c_plan_handle);
	end catch
	
	fetch next from cur_plan_handles into @c_plan_handle;
end 
close cur_plan_handles
deallocate cur_plan_handles;