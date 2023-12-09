/* Get Replication Involved Servers */
select s.server_id, s.name as srv_name, s.data_source, s.is_linked, 
		s.is_system, s.is_distributor, s.is_publisher, s.is_subscriber,
		s.is_nonsql_subscriber, s.modify_date
from sys.servers s
where is_distributor = 1 or is_publisher = 1 or is_subscriber = 1
order by (case when is_distributor = 1 then 0 when is_publisher = 1 then 1 else 2 end), srv_name
go

/* Execute on Distributor Server */
use master
select 'use '+QUOTENAME(d.name) as [--TSQL--] from sys.databases d where d.is_distributor = 1;
GO

use [distribution]
go
set quoted_identifier off;
set nocount on;
go

IF OBJECT_ID('tempdb..#publications') IS NOT NULL
	DROP TABLE #publications;
select srv.srvname as publisher, pl.publisher_id, pl.publisher_db, pl.publication, pl.publication_id,
		pl.publication_type, case pl.publication_type when 0 then 'Transactional' when 1 then 'Snapshot' when 2 then 'Merge' else 'No idea' end as publication_type_desc,
		pl.immediate_sync, pl.allow_pull, pl.allow_push, pl.description,
		pl.vendor_name, pl.sync_method, pl.allow_initialize_from_backup
into #publications
from dbo.MSpublications pl (nolock) join MSreplservers srv on srv.srvid = publisher_id
order by srv.srvname, pl.publisher_db;

if object_id('tempdb..#subscriptions') is not null
	drop table #subscriptions;
select distinct srv.srvname as subscriber, sub.subscriber_id, sub.subscriber_db,
		sub.subscription_type, case sub.subscription_type when 0 then 'Push' when 1 then 'Pull' else 'Anonymous' end as subscription_type_desc,
		sub.publication_id, sub.publisher_db,
		sub.sync_type, (case sub.sync_type when 1 then 'Automatic' when 2 then 'No synchronization' else 'No Idea' end) as sync_type_desc,
		sub.status, (case sub.status when 0 then 'Inactive' when 1 then 'Subscribed' when 2 then 'Active' else 'No Idea' end) as status_desc
into #subscriptions
from dbo.MSsubscriptions sub (nolock) join dbo.MSreplservers srv on srv.srvid = sub.subscriber_id
where sub.subscriber_id >= 0;

select pl.publisher, pl.publisher_db, pl.publication, pl.publication_type_desc, sb.subscriber, sb.subscriber_db, sb.subscription_type_desc, sb.sync_type_desc, sb.status_desc
from #publications pl join #subscriptions sb on sb.publication_id = pl.publication_id and sb.publisher_db = pl.publisher_db
order by pl.publisher, pl.publisher_db, sb.subscriber, sb.subscriber_db, pl.publication;

/*
if object_id('tempdb..#MSarticles') is not null
	drop table #MSarticles;
select pl.publisher, pl.publisher_db, pl.publication, pl.publication_type_desc, sb.subscriber, sb.subscriber_db, sb.subscription_type_desc, sb.sync_type_desc, sb.status_desc, a.article, a.article_id, a.destination_object, a.source_owner, a.source_object, a.description, a.destination_owner
into #MSarticles
from #publications pl join #subscriptions sb on sb.publication_id = pl.publication_id and sb.publisher_db = pl.publisher_db
join dbo.MSarticles a with (nolock) on a.publication_id = pl.publication_id and a.publisher_db = pl.publisher_db;

select [table_name] = quotename(publisher_db)+'.'+quotename(source_owner)+'.'+quotename(source_object),
		*
from #MSarticles a
where a.publisher = 'SqlPractice'
or a.subscriber = 'SqlPractice'
order by a.publisher, a.publisher_db, a.publication, a.article
*/

declare @tsql_add_subscription nvarchar(4000);
declare @publisher sysname, @publisher_db sysname, @publication sysname, @subscriber sysname, @subscriber_db sysname, @subscription_type_desc varchar(20);
declare cur_publications cursor local forward_only for
			select pl.publisher, pl.publisher_db, pl.publication, sb.subscriber, sb.subscriber_db, sb.subscription_type_desc
			from #publications pl join #subscriptions sb on sb.publication_id = pl.publication_id and sb.publisher_db = pl.publisher_db
			order by pl.publisher, pl.publisher_db, sb.subscriber, sb.subscriber_db, pl.publication;

open cur_publications
fetch next from cur_publications into @publisher, @publisher_db, @publication, @subscriber, @subscriber_db, @subscription_type_desc;

while @@FETCH_STATUS = 0
begin
	set @tsql_add_subscription =
"
:CONNECT "+QUOTENAME(@publisher)+"
use ["+@publisher_db+"]
exec sp_dropsubscription @publication = N'"+@publication+"', @subscriber = N'"+@subscriber+"', @destination_db = N'"+@subscriber_db+"', @article = N'all';
go
exec sp_addsubscription @publication = N'"+@publication+"', @subscriber = N'"+@subscriber+"', @destination_db = N'"+@subscriber_db+"',
						@subscription_type = N'"+@subscription_type_desc+"', @article = N'all',
						@sync_type = N'replication support only'
go
"
	print @tsql_add_subscription

	fetch next from cur_publications into @publisher, @publisher_db, @publication, @subscriber, @subscriber_db, @subscription_type_desc;
end

close cur_publications
deallocate cur_publications

SELECT '*** Check Messages Tab for ScriptOut ***' as [-- Add Subscription --]


