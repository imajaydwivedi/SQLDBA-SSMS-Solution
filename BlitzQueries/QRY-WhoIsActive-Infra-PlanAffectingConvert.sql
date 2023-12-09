use DBA
go

;with cte_WhoIsActive as (
	select * ,row_rank = ROW_NUMBER()over(partition by program_name, login_name, database_name, sql_text order by reads desc)
	from dbo.WhoIsActive w
	where 1=1
	and w.collection_time between '2023-10-03 03:00' and '2023-10-03 20:00'
	and w.database_name not in ('DBA')
	and (w.query_plan is not null and convert(varchar(max),w.query_plan) like '%PlanAffectingConvert%')
)
select top 500 *
--into WhoIsActive_PlanAffectingConverts_2023Oct03
from cte_WhoIsActive w
where row_rank = 1
order by reads desc
go

--select *
--from WhoIsActive_PlanAffectingConverts_2023Oct03
