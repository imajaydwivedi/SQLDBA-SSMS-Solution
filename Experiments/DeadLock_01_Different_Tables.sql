use Practice;
go

create table dbo.TableA
( ID int identity(1,1) not null
	, Name varchar(50) not null
	, City varchar(100) null default 'Bangalore'
)
go

insert into dbo.TableA ( Name, City) values ('Ajay', DEFAULT);
insert into dbo.TableA ( Name, City) values ('Gaurav', 'Punjab');
insert into dbo.TableA ( Name, City) values ('Anil', 'Hyderabad');
insert into dbo.TableA ( Name, City) values ('Guru', 'Indore');
insert into dbo.TableA ( Name, City) values ('Prakash', 'Rewa');

create table dbo.TableB
( ID int identity(1,1) not null
	, FullName varchar(50) not null
	, Country varchar(100) null default 'India'
)
go

insert into dbo.TableB ( FullName, Country) values ('Pradeep Dwivedi', DEFAULT);
insert into dbo.TableB ( FullName, Country) values ('Vijay Mishra', DEFAULT);
insert into dbo.TableB ( FullName, Country) values ('Subham Tiwari', DEFAULT);
insert into dbo.TableB ( FullName, Country) values ('Govind Singh', DEFAULT);
insert into dbo.TableB ( FullName, Country) values ('Hari Prakash', DEFAULT);

/* Tran 01: step 01 */
use Practice;
begin tran
	update dbo.TableA 
	set City = 'Rewa'
	where Name = 'Ajay'

/* Tran 02: step 01 */
use Practice;
begin tran
	update dbo.TableB 
	set Country = 'US'
	where FullName = 'Vijay Mishra'