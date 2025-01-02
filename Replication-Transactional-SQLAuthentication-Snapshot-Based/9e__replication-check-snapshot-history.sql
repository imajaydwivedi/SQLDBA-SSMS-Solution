-- Get Snapshot Agent history
  -- Execute on [DistributorServer]
use [<DistributionDbNameHere>];
select	agent_id, runstatus, start_time, time, duration, comments, delivered_transactions,
		delivered_commands, delivery_rate, error_id, timestamp 
from dbo.MSsnapshot_history h
join dbo.MSsnapshot_agents a
	on a.id = h.agent_id
where 1=1
and a.publication = '<PublicationNameHere>'
and (	h.comments = 'Starting agent.'
	or	h.comments like '![100!%!] A snapshot of <TotalPublishedTablesCountHere> article(s) was generated.' escape '!'
	)
and start_time >= DATEADD(hour,-8,GETDATE())
order by start_time
go

