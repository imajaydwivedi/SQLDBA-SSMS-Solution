use StackOverflow
go

create or alter procedure dbo.usp_Bounties_and_Questions_by_Month
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/7672/bounties-and-questions-by-month
	-- Bounties and Questions by Month
	-- Computes the number of bounties awarded and the total bounty amount awarded each month, along with the number of questions asked.
	select Isnull(V.Year, P.Year), Isnull(V.Month, P.Month), V.Bounties, V.Amount,
	P.Questions
	FROM
	(
	select
	datepart(year, Posts.CreationDate) Year,
	datepart(month, Posts.CreationDate) Month,
	count(Posts.Id) Questions
	from Posts
	where PostTypeid = 1 -- 1 = Question
	group by datepart(year, Posts.CreationDate), datepart(month, Posts.CreationDate)
	) AS P
	left JOIN
	(
	select
	datepart(year, Votes.CreationDate) Year,
	datepart(month, Votes.CreationDate) Month,
	count(Votes.Id) Bounties,
	sum(Votes.BountyAmount) Amount
	from Votes
	where VoteTypeId = 9 -- 9 = BountyAwarded
	group by datepart(year, Votes.CreationDate), datepart(month, Votes.CreationDate)
	) AS V
	ON P.Year = V.Year AND P.Month = V.Month
	order by P.Year, P.Month
end
go

--exec dbo.usp_Bounties_and_Questions_by_Month
--go