--	01) Find replication jobs
select j.name, c.name, j.description from msdb.dbo.sysjobs_view as j inner join msdb.dbo.syscategories as c on c.category_id = j.category_id
	where j.enabled = 1
	and c.name like '%repl%'
	order by c.name

-- which database is the distributor?
select *
from sys.databases
where is_distributor = 1;

-- which server is configured as Distributor
select * 
from sys.servers s
where s.name like '%repl%'

-- Get information of Distribution db option settings
use distribution;
exec sp_helpdistributiondb