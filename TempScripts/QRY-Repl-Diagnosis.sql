exec sp_helpdb 'distribution'

exec sp_spaceused 'MSrepl_commands'
select 81161880/1024/1024, 14 9832 477           
-- 350934.00 MB

repl_clearcache

/*
use distribution
go

select --top 10 --txn.publisher_database_id, txn.xact_id, txn.xact_seqno, txn.entry_time
			--,cmds.article_id
		txn.publisher_database_id, convert(date,txn.entry_time) as entry_date, DATEPART(hh, entry_time) as [entry_hour], count(*) as cmd_counts
into DBA.dbo.MSrepl_commands_Since_May23_9AM
from MSrepl_commands cmds with (nolock)
join msrepl_transactions txn with (nolock)
on txn.xact_seqno = cmds.xact_seqno
where entry_time >= '2022-05-23 09:00:00.000'
group by txn.publisher_database_id, convert(date,txn.entry_time), DATEPART(hh, entry_time)

select top 1 *
from msrepl_transactions txn with (nolock)
order by txn.entry_time asc
go

use DBA
go
select dateadd(hour,cmds.entry_hour,convert(datetime,cmds.entry_date)) as [time], agnt.publisher_db, agnt.name as [logreader-agent-name], cmds.cmd_counts
from DBA.dbo.MSrepl_commands_Since_May23_9AM cmds
join distribution.dbo.MSpublisher_databases dbs
on dbs.id = cmds.publisher_database_id
join distribution.dbo.MSlogreader_agents agnt
on agnt.publisher_id = dbs.publisher_id and agnt.publisher_db = dbs.publisher_db
order by entry_date, entry_hour, publisher_database_id

select *
from distribution.dbo.MSlogreader_agents 
*/