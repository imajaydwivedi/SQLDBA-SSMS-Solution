
use dba

select  * 
from dbo.CommandLog r
where r.StartTime >= '2020-02-10 06:00:01.120'
and r.StartTime <= '2020-02-10 08:00:01.120'
and DatabaseName in ('YouTubeFiltered')
--and ErrorMessage is not null

-- 2020-02-10 07:17:57.660

select * from dbo.WhoIsActive_ResultSets r
where r.collection_time >= '2020-02-10 07:00:01.120'
and r.collection_time <= '2020-02-10 08:00:01.120'
and r.program_name in ('SQL Job = DBA - IndexOptimize_Modified - YouTubeFiltered')