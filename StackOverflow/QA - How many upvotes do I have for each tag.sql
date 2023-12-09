-- https://data.stackexchange.com/stackoverflow/query/785/how-many-upvotes-do-i-have-for-each-tag
-- How many upvotes do I have for each tag?
-- how long before I get tag badges?
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

USE StackOverflow;

-- How many upvotes do I have for each tag?
-- how long before I get tag badges?

DECLARE @UserId int = @id;
-- How many upvotes do I have for each tag?
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
ORDER BY UpVotes DESC;



/*
create nonclustered index nci_Posts_OwnerUserId on dbo.Posts(OwnerUserId, ParentId)
go
create nonclustered index nci_Votes_PostId__include_VoteTypeId on dbo.Votes(PostId) include (VoteTypeId)
go
CREATE NONCLUSTERED INDEX nci_Votes_VoteTypeId__include_PostId ON [dbo].[Votes] ([VoteTypeId]) INCLUDE ([PostId])
GO
create nonclustered index nci_Votes_PostId_VoteTypeId on dbo.Votes(PostId, VoteTypeId)
go
create nonclustered index nci_Votes_VoteTypeId_PostId on dbo.Votes(VoteTypeId, PostId)
go
*/
