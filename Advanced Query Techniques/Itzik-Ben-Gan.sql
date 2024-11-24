/*	Youtube -> https://www.youtube.com/watch?v=wV6LsJgHmVg
	SQLDay 2021 - Workarounds for T-SQL restrictions and limitations - Itzik Ben-Gan
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
  from nums left join dbo.dummy_columnstore_table on 1=0
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