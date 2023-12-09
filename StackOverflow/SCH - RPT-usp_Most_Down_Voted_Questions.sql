use StackOverflow
go

create or alter procedure dbo.usp_Most_Down_Voted_Questions
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/36660/most-down-voted-questions
	-- Most Down-Voted Questions
	-- The top 20 questions with the most down-votes (ignores up-votes)

	select top 20 count(v.postid) as 'Vote count', v.postid AS [Post Link],p.body
	from votes v 
	inner join posts p on p.id=v.postid
	where PostTypeId = 1 and v.VoteTypeId=3
	group by v.postid,p.body
	order by 'Vote count' desc
end
go

--exec dbo.usp_Most_Down_Voted_Questions
--go