use StackOverflow2010
GO

/*
select top 100 * from dbo.Users as u where Id in (1,4449743,26837,545629,61305,440595,4197,1717
*/

declare @dt date;
set @dt = '2010-12-17'

select *
from dbo.Users u
where convert(date,u.CreationDate) = @dt


