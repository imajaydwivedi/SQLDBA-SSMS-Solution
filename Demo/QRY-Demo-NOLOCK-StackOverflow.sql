use StackOverflow2013
go

-- Session 01
select count(*)
from dbo.Users with (nolock)
where DisplayName = 'alex'
go 30


-- Session 02
begin tran
	update dbo.Users
		set Location = N'Some place on earth where nobody can find me.',
			WebsiteUrl = N'https://www.youtube.com/watch?v=EqfAPZGKifA&ab_channel=BrentOzarUnlimited'
		where DisplayName <> 'alex'
go
rollback


