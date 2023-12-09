use DBA
go

declare @publisher sysname;
declare @publication nvarchar(1000);
declare @subscription nvarchar(1000);
declare @latency int;

;with cte_latency as (
  select h.publisher, publication_display_name, subscription_display_name, last_token_time = convert(varchar,last_token_time,120), last_token_latency = last_token_latency_seconds
  		,current_latency_seconds ,current_latency_seconds/60 as current_latency_minutes, current_latency_seconds/60/60 as current_latency_hours
  from DBA.dbo.vw_repl_latency h
  where 1 = 1
  and (@publisher is null or h.publisher like ('%'+@publisher+'%'))
  and (@publication is null or h.publication_display_name like ('%'+@publication+'%'))
  and (@subscription is null or h.subscription_display_name like ('%'+@subscription+'%'))
)
select *
from cte_latency
where (@latency is null or current_latency_seconds >= @latency)
and last_token_time <= DATEADD(minute,-90,getdate())
order by current_latency_seconds desc, last_token_latency desc