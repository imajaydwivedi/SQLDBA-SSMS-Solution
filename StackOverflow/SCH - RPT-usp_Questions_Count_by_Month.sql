use StackOverflow
go

create or alter procedure dbo.usp_Questions_Count_by_Month
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/1075285/questions-count-by-month
	-- Questions Count by Month
	SELECT date1, count(id) as cnt
	FROM (

	  SELECT 
		FORMAT (d.CreationDate, 'yy-MM') as [date1],
		(d.Id) as id
	  FROM Posts d  -- d=duplicate
		LEFT JOIN PostHistory ph ON ph.PostId = d.Id
		LEFT JOIN PostLinks pl ON pl.PostId = d.Id
		LEFT JOIN Posts o ON o.Id = pl.RelatedPostId  -- o=original
	  WHERE
		d.PostTypeId = 1  -- 1=Question
    
	  ) as t1
	group by date1
	order by date1
end
go

exec dbo.usp_Questions_Count_by_Month
go
