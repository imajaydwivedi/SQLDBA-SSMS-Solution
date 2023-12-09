use StackOverflow
go

create or alter procedure dbo.usp_Posts_containing_a_very_short_title
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/877/posts-containing-a-very-short-title
	-- Posts containing a very short title
	-- Posts containing a body that is less than 5 chars long

	select Id as [Post Link], Body, Score from Posts where Len(Title) < 12 and ParentId is null
end
go

exec dbo.usp_Posts_containing_a_very_short_title
go