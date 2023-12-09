-- https://data.stackexchange.com/stackoverflow/query/951/low-views-high-votes-yet-unanswered

-- Enter Query Title
-- Enter Query Description
select /* Low views, high votes yet unanswered */
		top 500 Id as [Post Link], Score, ViewCount from Posts 
where Score > 2 and ViewCount <> 0 and ParentId is null and AcceptedAnswerId is null
order by ViewCount asc