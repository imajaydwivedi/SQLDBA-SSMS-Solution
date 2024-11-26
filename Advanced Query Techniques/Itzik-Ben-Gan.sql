/*	Youtube -> https://www.youtube.com/watch?v=wV6LsJgHmVg
	SQLDay 2021 - Workarounds for T-SQL restrictions and limitations - Itzik Ben-Gan

	Youtube -> https://www.youtube.com/watch?v=UrwAXUco3jU
	Workarounds for T-SQL Restrictions and Limitations - Itzik Ben-Gan

	YouTube -> https://www.youtube.com/watch?v=hrK9ZsMin7A
	Missing TSQL Querying Features for Handling NULLs and for Data Analysis - Itzik Ben-Gan

	Youtube -> https://www.youtube.com/watch?v=3ADK1IRiXzg
	Beware of nondeterministic T-SQL code


*/

use StackOverflow
go

-- With index on Window function ORDER BY column, we avoid Sorting in Segment operator
select u.Id, u.DisplayName, u.Reputation, u.Location
		,row_id = ROW_NUMBER() over (order by Reputation desc)
from dbo.Users u
order by row_id asc
offset 0 rows fetch next 200 rows only;
go

-- What if I don't want to sory by any column and still want row numbering?
	-- "Constant Folding" concept leads to saving SORT order
select u.Id, u.DisplayName, u.Reputation, u.Location
		--,row_id = ROW_NUMBER() over (order by @@spid desc)
		--,row_id = ROW_NUMBER() over (order by (select 1) desc)
		--,row_id = ROW_NUMBER() over (order by 1/0 desc)
		--,row_id = ROW_NUMBER() over (order by (select null) desc)
		,row_id = ROW_NUMBER() over (order by @@trancount desc) /* This disables parallelism */
from dbo.Users u
order by row_id asc
offset 0 rows fetch next 200 rows only;
go

exec sp_BlitzIndex @TableName = 'Users';

-- Will we see SORT operation due to "<<order by Expression>>" when expression is same as column ??
	-- Order preserving expression <<u.Reputation as Rep>>
select u.Id, u.Reputation as Rep, u.Views from dbo.Users u order by Rep;

-- Will we see SORT operation due to "<<order by Expression>>" ??
	-- Is this "Order preserving" expression ??
select u.Id, u.Reputation+100 as Rep, u.Views from dbo.Users u order by Rep; /* No SORT */
select u.Id, u.Reputation+100-0 as Rep, u.Views from dbo.Users u order by Rep; /* SORT */
select u.Id, u.Reputation+(100-0) as Rep, u.Views from dbo.Users u order by Rep; /* SORT */
go

/* INLINE TVF */
create or alter function dbo.MyFunction(@add as int, @subtract as int) returns table
as
return
	select u.Id, u.Reputation+(@add-@subtract) as Rep, u.Views from dbo.Users u;
go

select * from dbo.MyFunction(100,0) order by Rep;
go

/* Procedure */
create or alter procedure #MyProcedure(@add as int, @subtract as int)
as
	select u.Id, u.Reputation+(@add-@subtract) as Rep, u.Views from dbo.Users u order by Rep;
go

exec #MyProcedure @add = 100, @subtract = 0;
go

/* Procedure */
create or alter procedure #MyProcedure(@add as int, @subtract as int)
as
	select u.Id, u.Reputation+(@add-@subtract) as Rep, u.Views from dbo.Users u order by Rep;
go

/* Does it have SORT */
exec #MyProcedure @add = 100, @subtract = 0;
go


/* Procedure */
create or alter procedure #MyProcedure(@add as int, @subtract as int)
as
	select u.Id, u.Reputation+(@add-@subtract) as Rep, u.Views 
	from dbo.Users u order by Rep
	option (recompile); -- Added extra
go

/* Does it have SORT */
exec #MyProcedure @add = 100, @subtract = 0;
go


-- drop table dbo.nums
create table dbo.dummy_columnstore_table (dummy_col int);
go
create clustered columnstore index dummy_columnstore_table on dbo.dummy_columnstore_table --order (num)
go

--- Get numbers
create or alter function dbo.get_nums(@low bigint = 1, @high bigint) returns table
as return 
with
  l0 as (select c from (values(1),(1),(1),(1),(1),(1),(1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) as d(c)),
  l1 as (select 1 as c from l0 as a cross join l0 as b),
  l2 as (select 1 as c from l1 as a cross join l1 as b),
  l3 as (select 1 as c from l2 as a cross join l2 as b),
  nums as (select row_number() over (order by (select 'constant')) as rownum from l3)

  select top (@high-@low+1) (@low-1)+rownum as n 
  from nums left join dbo.dummy_columnstore_table on 1=0 -- This is supposed to enable Batch Mode in query plan
  order by rownum;
go

declare @low bigint = 1, @high bigint = 10000000;
declare @n bigint;
select @n=n from dbo.get_nums(@low,@high) n
go


/* Procedure */
create or alter procedure #MyProcedure(@add as int, @subtract as int)
as
	select u.Id, u.Reputation+(@add-@subtract) as Rep, u.Views 
	from dbo.Users u order by Rep
	option (recompile); -- Added extra
go

/* Does it have SORT */
exec #MyProcedure @add = 100, @subtract = 0;
go

/*
Youtube -> https://www.youtube.com/watch?v=UrwAXUco3jU
	Workarounds for T-SQL Restrictions and Limitations - Itzik Ben-Gan
*/

select top 100 p.Title
		,latest = GREATEST(p.ClosedDate, p.CreationDate, p.LastActivityDate, p.LastEditDate)
		,earliest = SMALLEST(p.ClosedDate, p.CreationDate, p.LastActivityDate, p.LastEditDate)
from dbo.Posts p
where p.PostTypeId = 1;

-- Since TSQL does not have GREATEST, below is most feasible solution
select top 100 p.Title, p.ClosedDate, p.CreationDate, p.LastActivityDate, p.LastEditDate
		,latest = cal.latest
		,earliest = cal.earliest
from dbo.Posts p
cross apply (select min(date_col) as earliest, max(date_col) as latest
			from (values (ClosedDate), (CreationDate), (LastActivityDate), (LastEditDate)) date_columns (date_col)
			) cal
where p.PostTypeId = 1;



-- With index on Window function ORDER BY column, we avoid Sorting in Segment operator
select u.Id, u.DisplayName, u.Reputation, u.Location
		,row_id = ROW_NUMBER() over (order by Reputation, u.Id)
from dbo.Users u
order by row_id desc
offset 0 rows fetch next 200 rows only;
go

-- Check indexes in postgres
select * from check_indexes('public','users');

-- with index on window function order by column, we avoid sorting in segment operator
explain
(analyze, buffers, costs, verbose)
select u.id, u.displayname, u.reputation, u.location
		,row_number() over (order by reputation desc) as row_id
from users u
order by row_id asc
offset 0 rows fetch next 200 rows only;


/* Ordered Views
** Recommendation => Don't create ordered views
*/
go

-- Best reliable workaround is offset fetch
create or alter view dbo.top_users_by_reputation
as
select u.Id, u.DisplayName, u.Reputation, u.Location
from dbo.Users u
order by Reputation desc
offset (0+0) rows fetch next 100 rows only;
go

select *
from dbo.top_users_by_reputation
go

--------------------------------------------------------
/* Resusing column aliases */
--------------------------------------------------------

-- return questions asked on an end of the year day
	-- ERROR
select p.Title, p.CreationDate
		,year(p.CreationDate) as CreationYear
		,DATEFROMPARTS(CreationYear,12,31) as EndOfYear
from dbo.Posts p
where p.PostTypeId = 1
and CreationDate = EndOfYear
go

-- Most correct way
select p.Title, p.CreationDate
		,cy.CreationYear
		,eoy.EndOfYear
from dbo.Posts p
cross apply (select year(p.CreationDate) as CreationYear) cy
cross apply (select DATEFROMPARTS(CreationYear,12,31) as EndOfYear) eoy
where p.PostTypeId = 1
and CreationDate = EndOfYear
go



/*
YouTube -> https://www.youtube.com/watch?v=hrK9ZsMin7A
	Missing TSQL Querying Features for Handling NULLs and for Data Analysis - Itzik Ben-Gan
*/
use StackOverflow2013
go

declare @location varchar(225) = NULL;
select * from dbo.Users u
where 1=1
	-- non-sargable way to get result
and isnull(location, 'no-mans-land') = isnull(@location, 'no-mans-land')
	-- messed way to get result
and ((u.Location is null and @location is null) or u.Location = @location)
	-- cleaner way to get result
and exists (select u.Location intersect select @location )
	-- cleaner way to get result
;

/* **********************************************
	SORTing NULLs
Merge SORT algorthim for SORT operator
performance degration with more rows => N log N
*/

create index WebsiteUrl on dbo.Users (WebsiteUrl);
go

-- we need all NULL rows last.
select u.WebsiteUrl, u.Id
from dbo.Users u
where 1=1
	-- Problem is, this introduces SORT operator in query plan 
order by (case when WebsiteUrl is null then 0 else 1 end), WebsiteUrl, Id;


-- we need all NULL rows last.
;with cte as 
(	
	select u.WebsiteUrl, u.Id, 0 as SortCol from dbo.Users u where u.WebsiteUrl is null
	UNION ALL
	select u.WebsiteUrl, u.Id, 1 as SortCol from dbo.Users u where u.WebsiteUrl is NOT null
)
select WebsiteUrl, Id
from cte
order by SortCol, WebsiteUrl, Id;
go




/* NULL treatment clause (IGNORE NULLS | RESPECT NULLS)

> Available in sql standard to offset window functions like LAG & LEAD
> IGNORE NULLs mean keep going until a non-NULL value found
*/

--drop table t1
select *
into t1
from (values (2,null),(3,10),(5,-1),(7,null),(11,null),(13,-12),(17,null),(19,null),(23,1759)) mytable(id, col1);

select * from t1;

-- supposed to be working, but not
select id, col1,
	COALESCE(col1, LAG(col1) IGNORE NULLS OVER (ORDER BY id)) as lastval
from dbo.T1

;with groupings as (
	select id, col1,
		max(case when col1 is not null then id end) over (order by id) as grp
	from dbo.T1
)
select id, col1, lastval = max(col1) over (partition by grp order by id rows unbounded preceding)
from groupings;


/* ************************************************************************************
** ROW PATTERN RECOGNITION
https://www.postgresql.org/message-id/fdf57a8d-65d5-e8a5-361f-3095d6899099%40postgresfriends.org
https://www.microsoft.com/en-us/research/uploads/prod/2022/05/match_recognize.pdf
https://sqlperformance.com/2019/04/t-sql-queries/row-pattern-recognition-in-sql
** ***********************************************************************************/



