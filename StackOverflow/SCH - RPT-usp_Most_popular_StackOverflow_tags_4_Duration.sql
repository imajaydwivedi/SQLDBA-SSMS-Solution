use StackOverflow
go

create or alter procedure dbo.usp_Most_popular_StackOverflow_tags_4_Duration @StartDate date, @EndDate date
as
begin
	-- Most popular StackOverflow tags in May 2010
	select 
		   num.TagName as Tag,
		   row_number() over (order by rate.Rate desc) as MayRank,
		   row_number() over (order by num.Num desc) as TotalRank,
		   rate.Rate as QuestionsInMay,
		   num.Num as QuestionsTotal

	from

	(select count(PostId) as Rate, TagName
	from
	  Tags, PostTags, Posts
	where Tags.Id = PostTags.TagId and Posts.Id = PostId
	and Posts.CreationDate <= @EndDate
	and Posts.CreationDate >= @StartDate
	group by TagName) as rate

	INNER JOIN

	(select count(PostId) as Num, TagName
	from
	  Tags, PostTags, Posts
	where Tags.Id = PostTags.TagId and Posts.Id = PostId
	group by TagName
	having count(PostId) > 800)
	as num ON rate.TagName = num.TagName
	order by rate.rate desc;
end
go

exec dbo.usp_Most_popular_StackOverflow_tags_4_Duration @StartDate = '2015-01-01', @EndDate = '2015-02-01'
go