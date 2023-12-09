USE [DBA]
-- Find long running statements of session
declare @table_name nvarchar(225) --= 'Posts';
declare @no_of_days tinyint = 7;
declare @database_name nvarchar(255) = 'StackOverflow';
declare @login_name nvarchar(255) = 'lab\sqluser';
declare @program_name nvarchar(255) = 'SQL Job = UpdateUserUpVotes';
declare @index_name nvarchar(255);
declare @duration_threshold_minutes smallint = 0;
declare @memory_threshold_mb smallint = 10;
declare @sql nvarchar(max);
declare @order_by varchar(50) = 'cpu'; /* cpu, reads, counts */

declare @crlf nvarchar(10) = char(13)+char(10);
set quoted_identifier off;
set @sql = "
;with xmlnamespaces ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' as qp),
t_queries as (
	select	* 
			,[sql_handle] = additional_info.value('(/additional_info/sql_handle)[1]','varchar(500)')
			--,[plan_handle] = additional_info.value('(/additional_info/plan_handle)[1]','varchar(500)')
			,[command_type] = additional_info.value('(/additional_info/command_type)[1]','varchar(50)')
			,[query_hash] = query_plan.value('(/*:ShowPlanXML/*:BatchSequence/*:Batch/*:Statements/*:StmtSimple)[1]/@QueryHash','varchar(100)')
			,[query_plan_hash] = query_plan.value('(/*:ShowPlanXML/*:BatchSequence/*:Batch/*:Statements/*:StmtSimple)[1]/@QueryPlanHash','varchar(100)')
			,[NonParallelPlanReason] = query_plan.value('(/*:ShowPlanXML/*:BatchSequence/*:Batch/*:Statements/*:StmtSimple/*:QueryPlan)[1]/@NonParallelPlanReason','varchar(200)')
			--,[optimization_level] = query_plan.value('(/*:ShowPlanXML/*:BatchSequence/*:Batch/*:Statements/*:StmtSimple)[1]/@StatementOptmLevel', 'sysname')
			--,[early_abart_reason] = query_plan.value('(/*:ShowPlanXML/*:BatchSequence/*:Batch/*:Statements/*:StmtSimple)[1]/@StatementOptmEarlyAbortReason', 'sysname')
			--,[CardinalityEstimationModelVersion] = query_plan.value('(/*:ShowPlanXML/*:BatchSequence/*:Batch/*:Statements/*:StmtSimple)[1]/@CardinalityEstimationModelVersion','int')
			,[used_memory_mb] = convert(numeric(20,2),convert(bigint,replace(used_memory,',',''))*8.0/1024)
			,[duration_minutes] = datediff(minute,start_time,collection_time)
	from dbo.WhoIsActive w	
	where w.collection_time >= dateadd(day,-@no_of_days,getdate()) and w.collection_time <= getdate()
	and additional_info.value('(/additional_info/command_type)[1]','varchar(50)') not in ('ALTER INDEX','UPDATE STATISTICS','DBCC','BACKUP LOG','BACKUP DATABASE')
	"+(case when @database_name is null then "--" else '' end)+"and w.database_name = @database_name
	"+(case when @table_name is null then "--" else '' end)+"and (	convert(nvarchar(max),w.sql_text) like ('%[[. ]'+@table_name+'[!] ]%') escape '!' or convert(nvarchar(max),w.query_plan) like ('%Table=""!['+@table_name+'!]""%') escape '!' )
	"+(case when @login_name is null then "--" else '' end)+"and w.login_name = @login_name
	"+(case when @program_name is null then "--" else '' end)+"and [program_name] = @program_name
	"+(case when @duration_threshold_minutes <= 0 then "--" else '' end)+"and duration_minutes >= @duration_threshold_minutes
	--and convert(varchar(max),w.query_plan) like ('%Database=""!['+@database_name+'!]"" Schema=""![dbo!]"" Table=""!['+@table_name+'!]"" Index=""!['+@index_name+'!]""%""') escape '!'
)
,t_capture_interval as (
	select [capture_interval_sec] = DATEDIFF(SECOND,snap1.collection_time_min, collection_time_snap2) 
	from (select min(collection_time) as collection_time_min from t_queries) snap1
	outer apply (select min(s2.collection_time) as collection_time_snap2 from t_queries s2 where s2.collection_time > snap1.collection_time_min) snap2
)
,top_queries as (
	select	*,
			[query_identifier] = left((case when [query_hash] is not null then [query_hash] 
											when [sql_handle] is not null then [sql_handle]
											else isnull(convert(varchar(max), sql_text),convert(varchar(max), [sql_command])) 
											end),20)
			,[query_hash_count] = COUNT(session_id)over(partition by (case when [query_hash] is not null then [query_hash] 
																		  when [sql_handle] is not null then [sql_handle]
																		  else isnull(convert(varchar(max), sql_text),convert(varchar(max), [sql_command]))
																		  end))
			,[query_identifier_rowid] = ROW_NUMBER()over(partition by left((case when [query_hash] is not null then [query_hash] 
											when [sql_handle] is not null then [sql_handle]
											else isnull(convert(varchar(max), sql_text),convert(varchar(max), [sql_command])) 
											end),20) order by [start_time] asc)
	from t_queries w
	--where [used_memory_mb] > @memory_threshold_mb
)
select top 1000 [collection_time], --[dd hh:mm:ss.mss], 
		[dd hh:mm:ss.mss] = right('0000'+convert(varchar, duration_minutes*60*1000/86400000),3)+ ' '+convert(varchar,dateadd(MILLISECOND,duration_minutes*60*1000,'1900-01-01 00:00:00'),114),
		[query_identifier],[capture_interval_sec],
		--[qry_time_min(~)] = ceiling([query_hash_count]*[capture_interval_sec]/60), 
		[query_hash_count],
		[session_id], [blocking_session_id], [command_type], [sql_text], [query_hash], 
		[sql_handle], [CPU], [used_memory_mb], [open_tran_count], 
		[status], [wait_info], [sql_command], [blocked_session_count], [reads], [writes], [tempdb_allocations], [tasks], [query_plan], 
		[query_plan_hash], [NonParallelPlanReason], [host_name], [additional_info], [program_name], [login_name], [database_name], [duration_minutes],
		[batch_start_time] = [start_time]
		,[estimated_cpu] = [CPU]*[query_hash_count]
		,[estimated_reads] = [reads]*[query_hash_count]
from top_queries,t_capture_interval
where [query_identifier_rowid] = 1
"+(case when @order_by = 'cpu' then '' else '--' end)+"order by [estimated_cpu] desc, [query_hash_count] desc
"+(case when @order_by = 'counts' then '' else '--' end)+"order by [query_hash_count] desc, [estimated_cpu] desc
"+(case when @order_by = 'reads' then '' else '--' end)+"order by [estimated_reads] desc, [query_hash_count] desc
option (recompile);
"
set quoted_identifier on;

print @sql

exec sp_ExecuteSql @sql, N'@table_name nvarchar(225),
						@no_of_days tinyint = 7,
						@database_name nvarchar(255) = NULL, 
						@login_name nvarchar(255) = NULL,
						@program_name nvarchar(255) = NULL,
						@index_name nvarchar(255) = NULL, 
						@duration_threshold_minutes smallint = 0,
						@memory_threshold_mb smallint = 20', 
						@table_name, @no_of_days , @database_name, @login_name, @program_name, 
						@index_name, @duration_threshold_minutes, @memory_threshold_mb
/*
select top 10000 sql_text2 = convert(xml,(select sql_text for xml path(''))),*
from dbo.xevent_metrics rc
where rc.event_time >= dateadd(day,-7,getdate()) and event_time <= getdate()
and (	convert(nvarchar(max),sql_text) like '%[[. ]User_Posts[!] ]%' escape '!' )

*/