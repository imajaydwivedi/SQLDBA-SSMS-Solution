use StackOverflow
go

create or alter procedure dbo.usp_Users_by_Popular_Question_ratio
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/2777/users-by-popular-question-ratio
	-- Users by Popular Question ratio
	-- (only users with at least 10 Popular Questions)

	select top 100
	  Users.Id as [User Link],
	  BadgeCount as [Popular Questions],
	  QuestionCount as [Total Questions],
	  CONVERT(float, BadgeCount)/QuestionCount as [Ratio]
	from Users
	inner join (
	  -- Popular Question badges for each user
	  select
		UserId,
		count(Id) as BadgeCount
	  from Badges
	  where Name = 'Popular Question'
	  group by UserId
	) as Pop on Users.Id = Pop.UserId
	inner join (
	  -- Questions by each user
	  select
		OwnerUserId,
		count(Id) as QuestionCount
	  from posts
	  where PostTypeId = 1
	  group by OwnerUserId
	) as Q on Users.Id = Q.OwnerUserId
	where BadgeCount >= 10
	order by [Ratio] desc;
end
go

exec dbo.usp_Users_by_Popular_Question_ratio
go

