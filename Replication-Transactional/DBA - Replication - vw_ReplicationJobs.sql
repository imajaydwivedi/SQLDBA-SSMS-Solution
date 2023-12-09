use dba
go

alter view vw_ReplicationJobs
as
-- To find Status of Replication Jobs
select --s.job_id,
		c.name as category_name, coalesce(d.publisher_db, j.publisher_db) as publisher_db, 
		coalesce(d.publication,j.publication) as publication,
		s.name as job_name,s.enabled as is_enabled, DBA.dbo.fn_IsJobRunning(s.name) as is_running
from msdb.dbo.sysjobs s inner join msdb.dbo.syscategories c on s.category_id = c.category_id
left join distribution.dbo.MSlogreader_agents as j
on j.name = s.name
left join distribution.dbo.MSdistribution_agents as d
on d.name = s.name
where c.name in ('REPL-Merge','REPL-Distribution','REPL-LogReader')
go