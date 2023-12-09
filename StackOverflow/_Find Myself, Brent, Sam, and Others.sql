use StackOverflow;
select top 100 * from dbo.Users as u where Id in (1,4449743,26837,545629,61305,440595,4197,17174);

SELECT TOP (1) Id FROM dbo.Users --where Id in (1,4449743,26837,545629,61305,440595,4197,17174) 
ORDER BY NEWID();

/*
select top 100 * from dbo.Users as u
	--where Id in (1,4449743,26837,545629)
	--where u.DisplayName IN ('Brent Ozar')
	where u.Reputation >= 100
	and u.DisplayName like '%Sam Saffron%'
	--where u.WebsiteUrl like '%ajaydwivedi%'
	order by u.Reputation desc
*/

--	EXEC sp_WhoIsActive @get_plans = 1