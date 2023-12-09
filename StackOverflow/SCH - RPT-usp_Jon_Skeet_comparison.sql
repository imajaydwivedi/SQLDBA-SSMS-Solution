use StackOverflow
go

create or alter procedure dbo.usp_Jon_Skeet_comparison @UserId int
as 
begin
	-- https://data.stackexchange.com/stackoverflow/query/3160/jon-skeet-comparison
	-- Jon Skeet comparison

	with fights as (
	  select myAnswer.ParentId as Question,
	   myAnswer.Score as MyScore,
	   jonsAnswer.Score as JonsScore
	  from Posts as myAnswer
	  inner join Posts as jonsAnswer
	   on jonsAnswer.OwnerUserId = 22656 and myAnswer.ParentId = jonsAnswer.ParentId
	  where myAnswer.ownerUserId = @UserId and myAnswer.postTypeId = 2
	)

	select
	  case
	   when myScore > JonsScore then 'You win'
	   when myScore < JonsScore then 'Jon wins'
	   else 'Tie'
	  end as 'Winner',
	  Question as [Post Link],
	  myScore as 'My score',
	  jonsScore as "Jon's score"
	from fights;
end
go

exec dbo.usp_Jon_Skeet_comparison @UserId = 545629
go