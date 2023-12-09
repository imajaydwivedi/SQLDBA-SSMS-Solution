use DBA
go

declare @duration_minutes_threshold int = 0;

if object_id('tempdb..#parameter_sniffing') is not null
	drop table #parameter_sniffing;

-- Find long running statements of session
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
	from dbo.WhoIsActive w
	where w.collection_time between dateadd(day,-5,getdate()) and getdate()	
	--and w.login_name = '' and w.database_name = 'StackOverflow'
	--and w.program_name like 'SQL Job = User Votes Upvotes Tally%'
	--and w.session_id = 164
)
,top_queries as (
	select	*,
			[query_identifier] = left((case when [query_hash] is not null then [query_hash] else [sql_handle] end),20),
			--[query_hash_count] = COUNT(session_id)over(partition by session_id, program_name, login_name, (case when [query_hash] is not null then [query_hash] else [sql_handle] end), isnull(convert(varchar(max), sql_text),convert(varchar(max), [sql_command])))
			[query_hash_count] = COUNT(session_id)over(partition by (case when [query_hash] is not null then [query_hash] 
																		  when [sql_handle] is not null then [sql_handle]
																		  else isnull(convert(varchar(max), sql_text),convert(varchar(max), [sql_command]))
																		  end))
	from t_queries w
	--where [used_memory_mb] > 500
)
select [collection_time], [dd hh:mm:ss.mss], [query_identifier], 
		[query_hash_id] = DENSE_RANK()over(order by [query_hash]),		
		[query_hash], [query_plan_hash], [query_hash_count], [distinct_query_plan_count],
		[session_id], [blocking_session_id], [command_type], [sql_text], [CPU], [used_memory_mb], [open_tran_count], 
		[status], [wait_info], [sql_command], [blocked_session_count], [reads], [writes], [tempdb_allocations], [tasks], [query_plan], 
		[NonParallelPlanReason], [host_name], [additional_info], [program_name], [login_name], [database_name], [duration_minutes],
		[batch_start_time] = [start_time], [Parameters] = TRY_CONVERT(XML,SUBSTRING(convert(nvarchar(max),w.query_plan),CHARINDEX('<ParameterList>',convert(nvarchar(max),w.query_plan)), CHARINDEX('</ParameterList>',convert(nvarchar(max),w.query_plan)) + LEN('</ParameterList>') - CHARINDEX('<ParameterList>',convert(nvarchar(max),w.query_plan)) ))
		,[query_hash_row_id]  = ROW_NUMBER()over(partition by [query_hash], [query_plan_hash] order by [duration_minutes] desc)
into #parameter_sniffing
from top_queries as w
cross apply (select [distinct_query_plan_count] = count(distinct [query_plan_hash]) from t_queries tq where tq.query_hash = w.query_hash) sniff
where w.duration_minutes >= @duration_minutes_threshold and [distinct_query_plan_count] > 1;

select [Compiled_Parameters] = convert(xml,pc.[Parameters]), ps.*
from #parameter_sniffing ps
outer apply (	
				select STUFF(( SELECT ', '+ [Parameter Name]+' = '+[compiled Value]
				from (	
					select [Parameter Name] = pc.compiled.value('@Column', 'nvarchar(128)'),
							[compiled Value] = pc.compiled.value('@ParameterCompiledValue', 'nvarchar(128)')
					from ps.[Parameters].nodes('//ParameterList/ColumnReference') AS pc(compiled)
				) pc
				ORDER BY [Parameter Name]
				FOR XML PATH('')), 1, 1, '') AS [Parameters]
			) pc
where [query_hash_row_id] = 1
order by [distinct_query_plan_count] desc, [query_hash], [duration_minutes]
go

