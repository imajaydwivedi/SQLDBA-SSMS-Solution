-- Get Snapshot Agent history
  -- Execute on [DistributorServer]
use [<DistributionDbNameHere>];
select	agent_id, runstatus, start_time, time, duration, comments, delivered_transactions,
		delivered_commands, delivery_rate, error_id, timestamp 
from dbo.MSsnapshot_history h
join dbo.MSsnapshot_agents a
	on a.id = h.agent_id
where 1=1
and publication = '<PublicationNameHere>'
and (	comments = 'Starting agent.'
	or	comments like '![100!%!] A snapshot of <TotalPublishedTablesCountHere> article(s) was generated.' escape '!'
	)
order by start_time
go

