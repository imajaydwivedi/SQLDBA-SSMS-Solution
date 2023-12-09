use distribution
go

IF OBJECT_ID('tempdb..#publications') IS NOT NULL
	DROP TABLE #publications;
select srv.name as publisher, pl.publisher_id, pl.publisher_db, pl.publication, pl.publication_id,
		pl.publication_type, case pl.publication_type when 0 then 'Transactional' when 1 then 'Snapshot' when 2 then 'Merge' else 'No idea' end as publication_type_desc, 
		pl.immediate_sync, pl.allow_pull, pl.allow_push, pl.description,
		pl.vendor_name, pl.sync_method, pl.allow_initialize_from_backup
into #publications
from dbo.MSpublications pl (nolock) join sys.servers srv on srv.server_id = publisher_id
order by srv.name, pl.publisher_db;

if object_id('tempdb..#subscriptions') is not null
	drop table #subscriptions;
select distinct srv.name as subscriber, sub.subscriber_id, sub.subscriber_db, 
		sub.subscription_type, case sub.subscription_type when 0 then 'Push' when 1 then 'Pull' else 'Anonymous' end as subscription_type_desc,
		sub.publication_id, sub.publisher_db, 
		sub.sync_type, (case sub.sync_type when 1 then 'Automatic' when 2 then 'No synchronization' else 'No Idea' end) as sync_type_desc, 
		sub.status, (case sub.status when 0 then 'Inactive' when 1 then 'Subscribed' when 2 then 'Active' else 'No Idea' end) as status_desc
into #subscriptions
from dbo.MSsubscriptions sub (nolock) join sys.servers srv on srv.server_id = sub.subscriber_id
where sub.subscriber_id >= 0;

select pl.publisher, pl.publisher_db, pl.publication, pl.publication_id, pl.publication_type_desc, sb.subscriber, sb.subscriber_db, sb.subscription_type_desc, sb.sync_type_desc, sb.status_desc
from #publications pl join #subscriptions sb on sb.publication_id = pl.publication_id and sb.publisher_db = pl.publisher_db
order by pl.publisher, pl.publisher_db, sb.subscriber, sb.subscriber_db, pl.publication;