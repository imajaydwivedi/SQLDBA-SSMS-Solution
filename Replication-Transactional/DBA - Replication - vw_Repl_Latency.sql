use DBA;
go
alter view dbo.vw_Repl_Latency
as
with t_Tokens as (
	select *, row_number()over(partition by publication order by ID) as rowID
	from DBA..Repl_TracerToken_Header h where h.is_processed = 0
)
,t_History as (
	select *, row_number()over(partition by publication order by collection_time desc) as rowID
	from DBA..[Repl_TracerToken_History]
	where publication not in (select t.publication from t_Tokens as t)
)
select	top 100 publication, currentTime, publisher_commit, Latest_Latency, Token_State
from (
	select publication, getdate() as currentTime, publisher_commit, datediff(minute,publisher_commit,getdate()) as Latest_Latency, 'Active' as Token_State
	from t_Tokens
	where rowID = 1
	--
	union all
	--
	select publication, getdate() as currentTime, publisher_commit, overall_latency, 'History' as Token_State
	from t_History
	where rowID = 1
) as t
order by publication;
go

--	select * from DBA..vw_Repl_Latency