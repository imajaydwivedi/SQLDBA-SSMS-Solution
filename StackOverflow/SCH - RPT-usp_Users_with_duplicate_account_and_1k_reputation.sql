use StackOverflow
go

create or alter procedure dbo.usp_Users_with_duplicate_account_and_1k_reputation
as
begin
	-- https://data.stackexchange.com/stackoverflow/query/975/users-with-more-than-one-duplicate-account-and-a-more-than-1000-reputation-in-agg
	-- Users with more than one duplicate account and a more that 1000 reputation in aggregate
	-- A list of users that have duplicate accounts on site, based on the EmailHash and lots of reputation is riding on it

	SELECT 
		u1.EmailHash,
		Count(u1.Id) AS Accounts,
		(
			SELECT Cast(u2.Id AS varchar) + ' (' + u2.DisplayName + ' ' + Cast(u2.reputation as varchar) + '), ' 
			FROM Users u2 
			WHERE u2.EmailHash = u1.EmailHash order by u2.Reputation desc FOR XML PATH ('')) AS IdsAndNames
	FROM
		Users u1
	WHERE
		u1.EmailHash IS NOT NULL
		and (select sum(u3.Reputation) from Users u3 where u3.EmailHash = u1.EmailHash) > 1000  
		and (select count(*) from Users u3 where u3.EmailHash = u1.EmailHash and Reputation > 10) > 1
	GROUP BY
		u1.EmailHash
	HAVING
		Count(u1.Id) > 1
	ORDER BY 
		Accounts DESC
end
go

exec  dbo.usp_Users_with_duplicate_account_and_1k_reputation