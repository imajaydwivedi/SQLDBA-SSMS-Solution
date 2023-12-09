USE StackOverflow
go

create table dbo.PostTags 
(	PostId int not null, 
	TagId int not null,
	constraint pk_PostTags primary key (PostId, Tagid),
	constraint fk_PostTags__PostId foreign key (PostId) references dbo.Posts (Id),
	constraint fk_PostTags__TagId foreign key (TagId) references dbo.Tags (Id)
);
go

alter table dbo.PostTags nocheck constraint fk_PostTags__PostId;
alter table dbo.PostTags nocheck constraint fk_PostTags__TagId;
GO

declare @counter int = 1;
declare @batch_size int = 10000;
while ( ((@counter-1)*@batch_size) <= (select MAX(id) from dbo.Posts) )
begin
	insert dbo.PostTags (PostId, TagId)
	select p.Id as PostId, t.Id as TagId
	from dbo.Posts as p
	outer apply
		( select ltrim(rtrim(pt.value)) as PostTag
		  from STRING_SPLIT(REPLACE(p.Tags,'<',''), '>') as pt
		  where ltrim(rtrim(pt.value)) <> ''
		  and p.Id > ((@counter-1)*@batch_size)
		and p.Id <= (@counter*@batch_size)
		) as pt
	join dbo.Tags as t
		on ltrim(rtrim(t.TagName)) = pt.PostTag
	where p.Id > ((@counter-1)*@batch_size)
		and p.Id <= (@counter*@batch_size)

	set @counter += 1;
end
go

alter table dbo.PostTags with check check constraint fk_PostTags__PostId;
alter table dbo.PostTags with check check constraint fk_PostTags__TagId;
GO
