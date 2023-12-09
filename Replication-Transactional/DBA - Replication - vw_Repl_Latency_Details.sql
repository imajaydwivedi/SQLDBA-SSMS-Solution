USE [DBA]
GO

CREATE view [dbo].[vw_Repl_Latency_Details]
as
/*
	Created By:	Ajay Dwivedi
	Purpose: Provide current Replication Latency with details
*/
with Tokens_Pending_Oldest as (
	select	t.publication, t.dbName, t.tracer_id, d.publisher_commit, d.distributor_commit, s.subscriber_commit
	from (
		select *, row_number()over(partition by publication order by ID) as rowID		
		from DBA..Repl_TracerToken_Header h where h.is_processed = 0
	  ) as t
	left join
		DistributorServer.distribution.dbo.MStracer_tokens as d with (nolock)
		on d.tracer_id = t.tracer_id
	left join
		DistributorServer.distribution.dbo.MStracer_history as s with (nolock)
		on s.parent_tracer_id = t.tracer_id
	where t.rowID = 1
)
,Tokens_Reached_Latest as (
	select	t.publication, t.subscriber_db, t.publisher_commit, t.distributor_commit, t.subscriber_commit
			,t.distributor_latency, t.subscriber_latency, t.overall_latency
	from (
		select *, row_number()over(partition by publication order by publisher_commit desc) as rowID		
		from DBA..Repl_TracerToken_History h
	  ) as t
	where t.rowID = 1
)
,t_History as (
	select coalesce(h.publication,a.publication) as publication, coalesce(h.subscriber_db,a.dbName) as subscriber_db
			,(case when a.tracer_id is null then 'History' else 'Active' end) as Token_State
			,(case when a.tracer_id is not null then datediff(minute,a.publisher_commit,getdate()) else h.overall_latency end) as current_Latency
			,a.publisher_commit, a.distributor_commit, a.subscriber_commit
			,[last_token_latency (publisher_commit)] = ((case when h.overall_latency > 0 then cast(h.distributor_latency as varchar(20))+' + '+cast(h.subscriber_latency as varchar(20))+' = '+cast(h.overall_latency as varchar(20)) else cast(h.overall_latency  as varchar(20)) end)+' ('+convert(varchar,h.publisher_commit,120)+') ')
	from Tokens_Pending_Oldest as a -- active tokens
	full outer join Tokens_Reached_Latest as h -- history tokens
		on h.publication = a.publication
)
select convert(varchar,getdate(),120) as currentTime, *
from t_History;
go