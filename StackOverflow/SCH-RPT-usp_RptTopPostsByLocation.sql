create or alter procedure dbo.usp_RptTopPostsByLocation @Location nvarchar(100)
as 
begin
/*
	exec usp_RptTopPostsByLocation N'London, United Kingdom'
*/
	select u.Id, u.DisplayName, p.Id as PostId, p.Title, p.Score
	from dbo.Users u
	inner join dbo.Posts p on u.Id = p.OwnerUserId
	where u.Location = @Location
	order by p.Score Desc, u.DisplayName
end
go

/* Put London in cache */
exec usp_RptTopPostsByLocation N'London, United Kingdom'
go


/* Try smaller location */
exec usp_RptTopPostsByLocation N'Nepal'
go