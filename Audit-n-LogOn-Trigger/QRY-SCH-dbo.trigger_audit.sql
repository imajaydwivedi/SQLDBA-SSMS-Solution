use DBA
go
-- drop table dbo.trigger_audit 
create table dbo.trigger_audit
(	[database_name] varchar(125) not null,
	[table_name] varchar(125) not null,
	action_type varchar(20) null,
	action_time datetime2 not null default sysdatetime(),
	original_login_name varchar(125) null default original_login(),
	effective_login_name varchar(125) null default suser_name(),
	client_app_name varchar(255) null,
	client_host_name varchar(255) null,
	session_id int null,
	identity_min bigint null,
	identity_max bigint null,
	remarks nvarchar(255) null,
)
go
create clustered index ci_trigger_audit on dbo.trigger_audit (action_time)
go

create table dbo.Person
(	id int identity(1,1) not null,
	name varchar(50) not null,
	city varchar(50) null
)
go

-- drop trigger dbo.tgr_dml__Person
go

create trigger dbo.tgr_dml__Person
	on dbo.Person
	after insert, update, delete
as 
begin
	declare @action_type varchar(20);
	declare @remarks nvarchar(255);
	declare @identity_min bigint;
	declare @identity_max bigint;

	if exists (select * from deleted) and exists (select * from inserted)
	begin
		set @action_type = 'update'
		select @remarks = convert(nvarchar, count(*)) + ' row(s) affected.'  from inserted;
	end
	if exists (select * from deleted) and not exists (select * from inserted)
	begin
		set @action_type = 'delete'
		select @remarks = convert(nvarchar, count(*)) + ' row(s) affected.'  from deleted;
	end
	if not exists (select * from deleted) and exists (select * from inserted)
	begin
		set @action_type = 'insert'
		select @remarks = convert(nvarchar, count(*)) + ' row(s) affected.'  from inserted;
	end

	/* If identity column exists */
	if @action_type = 'insert'
		select @identity_min = MIN(id), @identity_max = max(id) from inserted;

	insert dbo.trigger_audit
	(database_name, table_name, action_type, action_time, original_login_name, effective_login_name, client_app_name, client_host_name, session_id, identity_min, identity_max, remarks)
	select	database_name = DB_NAME(), 
			table_name = 'dbo.Person', 
			action_type = @action_type, 
			action_time = SYSDATETIME(), 
			original_login_name = ORIGINAL_LOGIN(), 
			effective_login_name = SUSER_NAME(), 
			client_app_name = APP_NAME(), 
			client_host_name = HOST_NAME(), 
			session_id = @@SPID, 
			identity_min = @identity_min, 
			identity_max = @identity_max, 
			remarks = @remarks
end
go

truncate table dbo.Person

insert dbo.Person (name, city)
select 'Ajay', 'Rewa'
go

insert dbo.Person (name, city)
select 'Saanvi', 'Rewa'
go

update dbo.Person set city = 'Hyderabad' where name = 'Saanvi'
go

delete dbo.Person where name = 'Saanvi'
go

select * from dbo.trigger_audit
go

--truncate table DBA.dbo.trigger_audit
--go
