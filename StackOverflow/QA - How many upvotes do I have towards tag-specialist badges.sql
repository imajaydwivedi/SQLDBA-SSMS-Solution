-- https://data.stackexchange.com/stackoverflow/query/2357/how-many-upvotes-do-i-have-towards-tag-specialist-badges

DECLARE @UserId int = ##UserId##

SELECT TOP 20 /* How many upvotes do I have towards tag-specialist badges */
    TagName,
    COUNT(*) AS UpVotes 
FROM Tags
    INNER JOIN PostTags ON PostTags.TagId = Tags.id
    INNER JOIN Posts ON Posts.ParentId = PostTags.PostId
    INNER JOIN Votes ON Votes.PostId = Posts.Id and VoteTypeId = 2
WHERE 
    Posts.OwnerUserId = @UserId
    AND Posts.CommunityOwnedDate IS NULL
GROUP BY TagName 
ORDER BY UpVotes DESC