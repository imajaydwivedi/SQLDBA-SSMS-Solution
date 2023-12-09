use StackOverflow
go
set statistics time on;
--set statistics io on;
go

select VoteTypeId, YEAR(CreationDate) as Yr, count(*) as VotesCast
from dbo.Votes
group by VoteTypeId, YEAR(CreationDate)
order by VoteTypeId, YEAR(CreationDate)
go

select VoteTypeId, YEAR(CreationDate) as Yr, count(*) as VotesCast
from dbo.Votes_columnstore_partitioned
group by VoteTypeId, YEAR(CreationDate)
order by VoteTypeId, YEAR(CreationDate)
/* 12 times, 33 seconds */
go


