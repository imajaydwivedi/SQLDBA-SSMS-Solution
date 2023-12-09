use StackOverflow
go

create or alter procedure dbo.usp_Posts_with_many_thank_you_answers
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/886/posts-with-many-thank-you-answers
	-- Posts with many "thank you" answers
	-- Looking at posts shorter than 200 with the text `hank` somewhere in it
	 select
	   ParentId as [Post Link],
	   count(id)
	from posts
	where posttypeid = 2 and len(body) <= 200
	  and (body like '%hank%')
	group by parentid
	having count(id) > 1
	order by count(id) desc;
end
go

exec dbo.usp_Posts_with_many_thank_you_answers
go