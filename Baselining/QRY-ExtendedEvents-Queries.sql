--
select xs.*, xst.*
from sys.dm_xe_sessions as xs
join sys.dm_xe_session_targets as xst
	on xst.event_session_address = xs.address
--where 
