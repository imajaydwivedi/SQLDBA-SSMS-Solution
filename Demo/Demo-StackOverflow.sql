use StackOverflow;

select *
from [dbo].[Users] as u
where u.DisplayName like '%Ajay%'
	and u.WebsiteUrl like '%ajaydwivedi.com%'


-- How many upvotes do I have for each tag?
-- how long before I get tag badges?

DECLARE @UserId int = 4449743

SELECT --TOP 20 
    TagName,
    COUNT(*) AS UpVotes 
FROM Tags
    INNER JOIN PostTags ON PostTags.TagId = Tags.id
    INNER JOIN Posts ON Posts.ParentId = PostTags.PostId
    INNER JOIN Votes ON Votes.PostId = Posts.Id and VoteTypeId = 2
WHERE 
    Posts.OwnerUserId = @UserId
GROUP BY TagName 
ORDER BY UpVotes DESC