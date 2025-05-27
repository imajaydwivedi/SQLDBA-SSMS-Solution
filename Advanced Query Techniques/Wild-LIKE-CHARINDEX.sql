select *
into ScratchPad.dbo.Users
from StackOverflow2013.dbo.Users u;
go

exec sp_BlitzIndex @TableName = 'Users'
go

create unique clustered index ci_Users on dbo.Users (Id)
go
create index DisplayName on dbo.Users (DisplayName, Id)
go

CREATE FULLTEXT CATALOG fulltextCatalog AS DEFAULT; 
go

CREATE FULLTEXT INDEX ON dbo.Users(DisplayName) 
KEY INDEX ci_Users 
WITH STOPLIST = SYSTEM;
go

set statistics io,time on;
select u.DisplayName, u.Id
from dbo.Users u
where 1=1
--and u.DisplayName like '%kumar%'
and contains (u.DisplayName, '%mitra%')
go

create or alter function dbo.SplitString
(
    @str nvarchar(4000), 
    @separator char(1)
)
returns table
AS
return (
    with tokens(p, a, b) AS (
        select 
            1, 
            1, 
            charindex(@separator, @str)
        union all
        select
            p + 1, 
            b + 1, 
            charindex(@separator, @str, b + 1)
        from tokens
        where b > 0
    )
    select
        p-1 zeroBasedOccurance,
        substring(
            @str, 
            a, 
            case when b > 0 then b-a ELSE 4000 end) 
        AS sub_str
    from tokens
    )
GO

select top 100 u.DisplayName, u.Id, pt.*
from dbo.Users u
cross apply (select * from dbo.SplitString(DisplayName, ' ') ss
			where 1=1
			--and sub_str <> ' '
			and sub_str = 'mitra'
			) pt



