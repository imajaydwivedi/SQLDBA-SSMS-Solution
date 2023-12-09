declare @publication_name varchar(300) = 'StackOverflowDE';

if object_id('tempdb..#ReplTokens') is not null
	drop table #ReplTokens;

select	t.publication, t.dbName, t.tracer_id, d.publisher_commit, d.distributor_commit, datediff(minute,d.publisher_commit,d.distributor_commit) as distributor_latency, s.subscriber_commit, datediff(minute,d.distributor_commit,s.subscriber_commit) as subscriber_latency
into #ReplTokens
from (
	select *, row_number()over(partition by publication order by ID) as rowID		
	from DBA..Repl_TracerToken_Header h 
	where h.publication = @publication_name
	--and h.is_processed = 0
	) as t
left join
	DistributorServer.distribution.dbo.MStracer_tokens as d with (nolock)
	on d.tracer_id = t.tracer_id
left join
	DistributorServer.distribution.dbo.MStracer_history as s with (nolock)
	on s.parent_tracer_id = t.tracer_id
where s.subscriber_commit is null or s.subscriber_commit >= dateadd(hour,-2,getdate())  -- Token not reached, or Token reached in past 2 hours

select * 
from #ReplTokens as a
where a.publisher_commit >= (select min(m.publisher_commit) from #ReplTokens as m where m.subscriber_commit is not null)