/*
exec sp_cycle_errorlog
go 10
*/
USE DBA
GO

set nocount on;

select *
from master.dbo.connection_limit_config with (nolock);
go

select convert(date,collection_time) as [date], DATEPART(hour,collection_time) as [hour],
		login_name, program_name, host_name, is_rejected_pseudo, count(1) as connections_counts
from DBA.dbo.connection_history with (nolock)
where collection_time between DATEADD(hour,-4,SYSDATETIME()) and SYSDATETIME()
group by convert(date,collection_time), DATEPART(hour,collection_time),
		login_name, program_name, host_name, is_rejected_pseudo
order by [date] desc, [hour] desc

-- select * from DBA.dbo.connection_history

--exec sp_WhoIsActive

-- truncate table DBA.dbo.connection_history