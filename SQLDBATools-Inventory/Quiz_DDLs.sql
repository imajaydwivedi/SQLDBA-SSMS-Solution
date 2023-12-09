use Quiz
go

create table dbo.Users
(	userid int identity(1,1),
	regtime datetime,
	username varchar(50),
	email varchar(50),
	userpass varchar(50)
);

create table dbo.QuestionTechnology
(	technologyid INT IDENTITY(1,1),
	category char(20),
	subcategory varchar(20),
	[level] int default 2,
	[description] varchar(255)
);
alter table dbo.QuestionTechnology
	add constraint PK_QuestionTechnology_technologyid PRIMARY KEY CLUSTERED (technologyid)
go

create table dbo.QuestionType
(
	typeid int identity(1,1),
	questiontype varchar(20),
	subtype varchar(20),
	[description] varchar(255)
);

