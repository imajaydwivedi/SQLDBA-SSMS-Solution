use DBA;
go

set nocount on;
set quoted_identifier on;

declare @c_publication varchar(200);
declare @c_publication_id int;
declare @c_dbName varchar(200);
declare @c_publisher_commit datetime;
declare @c_is_processed bit;
declare @c_tracer_id bigint;
declare @oldest_pending_publisher_commit datetime;
declare @tsqlString nvarchar(4000);

-- Find oldest tracer token yet to be processed in DBA table
select @oldest_pending_publisher_commit = dateadd(second,-5,min(collection_time))
from dbo.repl_token_header h where h.is_processed = 0;

if object_id('tempdb..#subs') is not null
	drop table #subs;
select srv_pub.name as publisher
		,[publication_display_name] = QUOTENAME(a.publisher_db)+': '+a.publication
	,[subscription_display_name] = QUOTENAME(srv_sub.name)+'.'+QUOTENAME(a.subscriber_db)
	,a.publisher_db, p.publication_id, a.publication, a.id as agent_id
	,a.name as agent_name, srv_sub.name as subscriber, a.subscriber_db
into #subs
from distribution.dbo.MSpublications as p with (nolock)
inner join master.sys.servers as srv_pub on srv_pub.server_id = p.publisher_id
left join distribution.dbo.MSdistribution_agents as a with (nolock)
on a.publication = p.publication and a.publisher_db = p.publisher_db and a.publisher_id = p.publisher_id
inner join master.sys.servers as srv_sub on srv_sub.server_id = a.subscriber_id


if object_id('tempdb..#tokens') is not null
	drop table #tokens;
select d.tracer_id, d.publication_id, d.publisher_commit, d.distributor_commit, h.parent_tracer_id, h.agent_id, h.subscriber_commit
into #tokens
from distribution.dbo.MStracer_tokens as d with (nolock)
left join distribution.dbo.MStracer_history as h with (nolock)
on h.parent_tracer_id = d.tracer_id
where d.publisher_commit >= @oldest_pending_publisher_commit;

--select top 3 * from #subs
--select top 3 * from #tokens

-- Find all tracer token history since oldest pending tracer token 
if object_id('tempdb..#MStracer_tokens') is not null
	drop table #MStracer_tokens;
select	subs.publisher, subs.[publication_display_name], subs.[subscription_display_name]
		,subs.publisher_db, subs.publication_id, subs.publication, tkn.tracer_id, tkn.publisher_commit, tkn.distributor_commit		
		,subs.agent_name, tkn.subscriber_commit, subs.subscriber, subs.subscriber_db		
		,[subscription_counts] = COUNT(*)OVER(PARTITION BY subs.publisher, subs.publisher_db, subs.publication_id)
into #MStracer_tokens
from #subs as subs
left join #tokens as tkn
on tkn.publication_id = subs.publication_id and tkn.agent_id = subs.agent_id;

/*
select * from #MStracer_tokens where tracer_id is null
select top 10 * from #subs where publication_id = 83
select top 3 * from #MStracer_tokens where publisher = 'SqlPractice' --and publication_display_name = '[Posts]: Posts_CLient2_to35' order by [subscription_display_name]
select top 3 * from dbo.repl_token_header where is_processed = 0
*/
begin tran
	--	Insert processed tokens in History Table
	insert dbo.[repl_token_history]
	(	[publisher], [publication_display_name], [subscription_display_name], [publisher_db], publication, publisher_commit, 
		distributor_commit, [distributor_latency], subscriber, subscriber_db, subscriber_commit, [subscriber_latency],
		[overall_latency], [agent_name]
	)
	select h.[publisher], h.[publication_display_name], h.[subscription_display_name], h.[publisher_db], h.publication, h.publisher_commit, 
			h.distributor_commit, [distributor_latency] = datediff(minute,h.publisher_commit,h.distributor_commit), h.subscriber, h.subscriber_db, 
			h.subscriber_commit, [subscriber_latency] = datediff(minute,h.distributor_commit,h.subscriber_commit),
			[overall_latency] = datediff(minute,h.publisher_commit,h.subscriber_commit), [agent_name] = h.agent_name
	from #MStracer_tokens as h
	join dbo.repl_token_header as b
	on b.publisher = h.publisher
	and b.publisher_db = h.publisher_db
	and b.publication_id = h.publication_id
	and b.token_id = h.tracer_id
	where b.is_processed = 0
	and h.subscriber_commit is not null;

	-- List Tokens pending for any subscription	
	if object_id('tempdb..#pending_tokens') is not null
		drop table #pending_tokens
	select distinct publisher, publisher_db, publication, publication_id, h.tracer_id
	into #pending_tokens
	from #MStracer_tokens as h
	where h.subscriber_commit is null;
	
	-- Mark tokens processed if reached all subscriptions
	update b
	set is_processed = 1
	-- select b.*, pt.tracer_id
	from #MStracer_tokens as h
	join dbo.repl_token_header as b
	on b.publisher = h.publisher
	and b.publisher_db = h.publisher_db
	and b.publication = h.publication 
	and b.publication_id = h.publication_id
	and b.token_id = h.tracer_id
	left join #pending_tokens pt
	on pt.publisher = h.publisher
	and pt.publisher_db = h.publisher_db
	and pt.publication = h.publication
	and pt.publication_id = h.publication_id
	and pt.tracer_id = h.tracer_id
	where b.is_processed = 0
	and pt.tracer_id is null;
commit tran
/*
 select top 3 * from dbo.[repl_token_history]
 select top 3 * from dbo.repl_token_header as b
 select top 3 * from #MStracer_tokens as h
*/

--	Update process flag for lost tokens
;with t_Repl_TracerToken_Lastest_Processed as (
	select publisher, publisher_db, publication, publication_id, max(collection_time) as last_publisher_commit 
	from dbo.repl_token_header 
	where is_processed = 1 
	group by publisher, publisher_db, publication, publication_id
)
update h
set is_processed = 1
--select h.*
from dbo.repl_token_header as h
inner join t_Repl_TracerToken_Lastest_Processed as l
on l.publication = h.publication and h.collection_time < l.last_publisher_commit
where h.is_processed = 0

/*
-- Get Latest Latency
select top 1 with ties h.publisher, publication_display_name, subscription_display_name, last_token_time = publisher_commit, last_token_latency_seconds = overall_latency
		,current_latency_seconds = datediff(second,collection_time_utc,SYSUTCDATETIME())
from dbo.[repl_token_history] h
order by ROW_NUMBER()over(partition by publisher, publication_display_name, subscription_display_name order by publisher_commit desc);

*/
