use dba

;with t1 as		
(
	select ROW_NUMBER()over(partition by cast(sql_command as varchar(max)), login_name, r.host_name, r.program_name order by datediff(minute,r.tran_start_time ,r.collection_time) desc) as ID, *, datediff(minute,r.tran_start_time ,r.collection_time) as tran_TimeInMinutes
	from dbo.whoisactive_resultsets r 
	where r.sql_command is not null
	and r.open_tran_count > 0
	and datediff(minute,r.tran_start_time ,r.collection_time) > 180 -- 3 hours
)
select * from t1 r where r.ID = 1 order by tran_TimeInMinutes desc, r.TimeInMinutes desc