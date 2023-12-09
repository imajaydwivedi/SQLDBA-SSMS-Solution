-- https://data.stackexchange.com/stackoverflow/query/466/most-controversial-posts-on-the-site
use StackOverflow
go

set nocount on 
-- Most controversial posts on the site
declare @VoteStats table (PostId int, up int, down int) 

insert @VoteStats
select
    PostId, 
    up = sum(case when VoteTypeId = 2 then 1 else 0 end), 
    down = sum(case when VoteTypeId = 3 then 1 else 0 end)
from Votes
where VoteTypeId in (2,3)
group by PostId

set nocount off


select top 100 p.id as [Post Link] , up, down from @VoteStats 
join Posts p on PostId = p.Id
where down > (up * 0.5) and p.CommunityOwnedDate is null and p.ClosedDate is null
order by up desc;