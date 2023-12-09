use StackOverflow
go

create or alter procedure dbo.usp_Total_Questions_and_Answers_per_Month @months tinyint = 12
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/6134/total-questions-and-answers-per-month-for-the-last-12
	-- Total Questions and Answers per Month for the last 12
	-- Total number of questions and answers for the last 12 months (in 30 day chunks)

	set nocount on 

	create table #ranges (Id int identity, [start] datetime, [finish] datetime)

	insert #ranges
	select top (@months) null, null
	from sysobjects

	declare @oldestPost dateTime

	select @oldestPost = CreationDate from Posts 
	where Id = (select max(p2.Id) from Posts p2)

	-- look at 30 day chunks, so stats remain fairly accurate 
	-- (month will depend on days per month)

	update #ranges 
	  set 
	   [start] = DateAdd(d, (0 - Id) * 30, @oldestPost),
	   [finish] = DateAdd(d, (1 - Id) * 30, @oldestPost)



	select start, (select count(*) from Posts where ParentId is null 
	   and CreationDate between [start] and [finish] ) as [Total Questions],
		(select count(*) from Posts where ParentId is not null 
	   and CreationDate between [start] and [finish] ) as [Total Answers]
	from #ranges
end
go

exec dbo.usp_Total_Questions_and_Answers_per_Month
go
