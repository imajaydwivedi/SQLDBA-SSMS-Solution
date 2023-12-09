use StackOverflow
go

create or alter procedure dbo.usp_Most_and_least_dangerous_tags_to_answer
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/1256/most-and-least-dangerous-tags-to-answer-among-the-tags-with-1000-questions
	-- Most and least dangerous tags to answer (among the tags with 1000+ questions)
	-- This query shows the number of upvotes, downvotes and D/U ratio for the answers to the most common tags
	WITH    q AS
	(
	SELECT  t.*,
			(
			SELECT  COUNT(*) AS cnt
			FROM    posttags pt
			JOIN    posts pp
			ON      pp.id = pt.postid
			JOIN    posts pa
			ON      pa.parentid = pp.id
			JOIN    votes v
			ON      v.postid = pa.id
			WHERE   pt.tagid = t.id
					AND v.votetypeid = 2
			) AS upvotes,
			(
			SELECT  COUNT(*) AS cnt
			FROM    posttags pt
			JOIN    posts pp
			ON      pp.id = pt.postid
			JOIN    posts pa
			ON      pa.parentid = pp.id
			JOIN    votes v
			ON      v.postid = pa.id
			WHERE   pt.tagid = t.id
					AND v.votetypeid = 3
			) AS downvotes
	FROM    Tags t
	CROSS APPLY
			(
			SELECT  COUNT(*) AS cnt
			FROM    PostTags pt
			WHERE   pt.tagid = t.id
			HAVING  COUNT(*) >= 1000
			) pt
	)
	SELECT  tagname AS [Tags], upvotes AS [Upvotes], downvotes AS [Downvotes], ROUND(100.0 * downvotes / NULLIF(upvotes, 0), 2) AS [D/U ratio]
	FROM    q
	ORDER BY
			4 DESC
end
go

exec dbo.usp_Most_and_least_dangerous_tags_to_answer
go