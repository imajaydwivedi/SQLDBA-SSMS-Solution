use StackOverflow
go

CREATE OR ALTER PROCEDURE dbo.usp_get_user_upvotes @UserId int
AS
BEGIN
	-- https://data.stackexchange.com/stackoverflow/query/785/how-many-upvotes-do-i-have-for-each-tag
	-- How many upvotes do I have for each tag?
	-- how long before I get tag badges?

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
END
GO

exec dbo.usp_get_user_upvotes @UserId = 545629
go