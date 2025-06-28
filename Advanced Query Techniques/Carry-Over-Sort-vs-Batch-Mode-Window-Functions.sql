/*	***************************************************************
	Carry Over Sort vs Batch Mode Window Functions (Erik Darling)
	https://www.youtube.com/watch?v=YyWfhrqmJYE

	Performance Comparision -> 
		a) CPU Time
		b) Execution Time
		c) Batch Mode vs RowStore Mode
		d) Memory Grants
		e) Older vs Newer Version of SQLServer
		f) With & Without Index
**	**************************************************************/

/*
set statistics time, io on;
*/
go

/* Original Query */
;with cte_posts as (
	select	p.PostTypeId, 
			CreationDate = ca.CreationDate,
			p.OwnerUserId,
			p.Id,
			rno = ROW_NUMBER() over (partition by p.PostTypeId
									order by ca.CreationDate desc, p.OwnerUserId desc, p.Id desc
									)
	from dbo.Posts p
	cross apply (select CreationDate = convert(date, p.CreationDate, 112)) ca
)
select cte.*
from cte_posts cte
where cte.rno = 1
order by PostTypeId
option (use hint('query_optimizer_compatibility_level_140'));
go

print '******************************************'
go

/*
drop index carry_over_sort on dbo.Posts;

create index carry_over_sort on dbo.Posts (PostTypeId, CreationDate desc, OwnerUserId desc, Id desc)
	with (maxdop = 0, data_compression = page);
go
*/


if OBJECT_ID('tempdb..#t') is null
	CREATE TABLE #t(id INT, INDEX c CLUSTERED COLUMNSTORE);

/* Carry Over Sort Method */
;with cte_posts as (
	select	p.PostTypeId,
			cols = max(
					CreationDate_Str
					+ (case when p.OwnerUserId < 0 then left(OwnerUserId_Str + 'XXXXXXXXX', 10) -- to handle "-1" UserIds
							else right('000000000'+OwnerUserId_Str,10)
						end)
					+ Id_Str
				)
	from dbo.Posts p
	left join #t as t
		on 1=0
	cross apply (select CreationDate_Str = convert(char(8), p.CreationDate, 112),
						OwnerUserId_Str = convert(varchar(10), p.OwnerUserId),
						Id_Str = convert(varchar(10), p.Id)
				) ca_i
	group by p.PostTypeId
)
select	cte.PostTypeId,
		CreationDate = convert(date, CreationDate_Str, 112),
		OwnerUserId = convert(int,replace(OwnerUserId_Str,'X','')),
		Id_Str = convert(int,Id_Str)
from cte_posts cte
cross apply (select CreationDate_Str = SUBSTRING(cte.cols, 1, 8),
					OwnerUserId_Str = SUBSTRING(cte.cols, 9, 10),
					Id_Str = SUBSTRING(cte.cols, 19, 10)
		) ca_o
order by cte.PostTypeId
option (use hint('query_optimizer_compatibility_level_140'));



