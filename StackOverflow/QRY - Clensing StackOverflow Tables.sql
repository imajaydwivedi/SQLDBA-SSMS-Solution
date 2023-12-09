use StackOverflow

select top 10 *
		,AcceptedAnswerId, LastEditorDisplayName, LastEditoruserId, OwnerUserId, ParentId, PostTypeId
from dbo.Posts


select COUNT(*) /* Invalid AcceptedAnswerId = 38976963*/
from dbo.Posts as p
where p.AcceptedAnswerId is not null
and p.AcceptedAnswerId not in (select i.Id from dbo.Posts as i)

select COUNT(*) /* Invalid AcceptedAnswerId */
from dbo.Posts as p
where p.LastEditoruserId not in (select u.Id from dbo.Users as u)