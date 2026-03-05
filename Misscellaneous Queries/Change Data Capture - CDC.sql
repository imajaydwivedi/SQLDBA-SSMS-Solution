-- Youtube - https://youtu.be/E0KpqD3SM1U?si=V2HM9tQypZA7eqmm

-- Step 1: Create a database for the CDC demo
create database CDCDemo;
go

-- Switch to the new database
use CDCDemo
go

-- Step 2: Enable CDC at the database level
exec sys.sp_cdc_enable_db;
go

-- Check CDC is enable
select is_cdc_enabled, * from sys.databases;

-- Step 3: Create a table to track changes
create table dbo.Employees (
	EmployeeID int identity(1,1) primary key,
	FirstName varchar(50),
	LastName varchar(50),
	Position varchar(50),
	Salary decimal(10,2)
);
go

-- Step 4: Enable CDC for the Employees table
exec sys.sp_cdc_enable_table
	@source_schema = 'dbo',
	@source_name = 'Employees',
	@role_name = NULL;
go

-- Step 5: Insert sample data into the table
insert into dbo.Employees (FirstName, LastName, Position, Salary)
values 
('Priti', 'Sharma', 'Engineer', 30000),
('Ajay', 'Dwivedi', 'Sr Engineer', 50000),
('Anant', 'Dwivedi', 'Analyst', 15000);
go

select * from Employees;

-- Step 6: Update some records to generate changes
update Employees
set Salary = 60000
where FirstName = 'Ajay';

update Employees
set Position = 'Sr Analyst'
where FirstName = 'Anant';

-- Step 7: View change data in CDC tables
select * from cdc.dbo_Employees_CT;

delete from Employees
where EmployeeID = 1;