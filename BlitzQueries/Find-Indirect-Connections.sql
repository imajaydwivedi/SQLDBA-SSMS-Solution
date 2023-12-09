select *
from dbo.WhoIsActive_ResultSets as r
where r.database_name <> 'Staging' --and collection_time ='2019-11-05 05:15:05.477'
and r.locks.exist('/Database[@name="Staging"]')=1