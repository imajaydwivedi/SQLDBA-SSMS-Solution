-- https://data.stackexchange.com/stackoverflow/query/7521/how-unsung-am-i
-- How Unsung am I?
-- Zero and non-zero accepted count. Self-accepted answers do not count.

select /* How Unsung am I? */
    count(a.Id) as [Accepted Answers],
    sum(case when a.Score = 0 then 0 else 1 end) as [Scored Answers],  
    sum(case when a.Score = 0 then 1 else 0 end) as [Unscored Answers],
    sum(CASE WHEN a.Score = 0 then 1 else 0 end)*1000 / count(a.Id) / 10.0 as [Percentage Unscored]
from
    Posts q
  inner join
    Posts a
  on a.Id = q.AcceptedAnswerId
where
      a.CommunityOwnedDate is null
  and a.OwnerUserId = @Id
  and q.OwnerUserId != @Id
  and a.postTypeId = 2;

