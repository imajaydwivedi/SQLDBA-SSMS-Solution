use DBA
go

--truncate table dbo.PlanCacheAutopilot

select top 100 *
from dbo.PlanCacheAutopilot pca
where pca.plan_generation_num > 10 order by pca.plan_generation_num desc /* Plans getting recompiled */
go

/* Get top queries by their Occurrences */
select top 200 query_hash, count(*) as recs, count(distinct query_plan_hash) as plan_count
from dbo.PlanCacheAutopilot pca
group by query_hash
having count(distinct query_plan_hash) > 1
order by plan_count desc, recs desc
go

/* Get Details of Queries by QueryHash */
select *
from dbo.PlanCacheAutopilot pca
where pca.query_hash in (0x9431F942971DCF00) --,0xA3912FBACA1D6ABA,0xF1A5416179C04CBF)
order by query_hash, query_plan_hash
go

;with xmlnamespaces ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' as qp),
t_whoisactive as (
	select * , [query_hash] = query_plan.value('(/*:ShowPlanXML/*:BatchSequence/*:Batch/*:Statements/*:StmtSimple)[1]/@QueryHash','varchar(100)')
			,[Parameters] = TRY_CONVERT(XML,SUBSTRING(convert(nvarchar(max),w.query_plan),CHARINDEX('<ParameterList>',convert(nvarchar(max),w.query_plan)), CHARINDEX('</ParameterList>',convert(nvarchar(max),w.query_plan)) + LEN('</ParameterList>') - CHARINDEX('<ParameterList>',convert(nvarchar(max),w.query_plan)) ))
	from dbo.WhoIsActive w
	where query_plan is not null
	and w.collection_time >= dateadd(hour,-9,getdate())
	
)
select --top 10 
		[Compiled_Parameters] = convert(xml,pc.[Parameters]),
		w.*
from t_whoisactive w
outer apply (	
				select STUFF(( SELECT ', '+ [Parameter Name]+' = '+[compiled Value]
				from (	
					select [Parameter Name] = pc.compiled.value('@Column', 'nvarchar(128)'),
							[compiled Value] = pc.compiled.value('@ParameterCompiledValue', 'nvarchar(128)')
					from w.[Parameters].nodes('//ParameterList/ColumnReference') AS pc(compiled)
				) pc
				ORDER BY [Parameter Name]
				FOR XML PATH('')), 1, 1, '') AS [Parameters]
			) pc
where w.query_hash = '0xC834931DA81DB695'
order by collection_time desc
option(fast 10)
go

/*
<?ClickMe 
SET ANSI_NULLS ON 
SET ANSI_PADDING ON 
SET ANSI_WARNINGS ON 
SET ARITHABORT  OFF 
SET CONCAT_NULL_YIELDS_NULL ON 
SET NUMERIC_ROUNDABORT OFF 
SET QUOTED_IDENTIFIER ON 

EXEC [dbo].[usp_SearchPostsByPostType]  @EndDate = '2011-11-02 00:00:00.000', @EndDate = '2011-11-30 00:00:00.000', @PostType = N'ModeratorNomination', @ResultsToShow = 100, @ResultsToShow = 10000, @StartDate = '2011-11-01 00:00:00.000'
?>
*/