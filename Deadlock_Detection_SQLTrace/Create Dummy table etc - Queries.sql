use DBA
go

-- Create table
create table dbo.Employee 
( ID int identity(1,1) primary key,
  Name varchar(50),
  Salary decimal(12,2)
)
go
--select * from dbo.Employee 

-- Populate 3 dummy records
insert dbo.Employee
select 'Ajay',2000000
union all
select 'Modi',800000
union all
select 'Gaurav',2800000

-- Notice SQL Agent service account
select * from sys.dm_server_services;

--	Session 01
SET DEADLOCK_PRIORITY 10;
begin tran
	update dbo.Employee
	set Salary = Salary + (0.12*Salary)
	where ID = 1;
	-- 
	WAITFOR DELAY '00:00:20';
	--
	select Salary
	from dbo.Employee where ID = 2;
rollback tran
go

--	Session 02
alter procedure dbo.usp_UpdateEmployeeSalary
as
BEGIN
begin tran
	update dbo.Employee
	set Salary = Salary + (0.20*Salary)
	where ID = 2;
	-- 
	WAITFOR DELAY '00:00:20';
	--
	select *
	from dbo.Employee --where ID = 1;
rollback tran
END
GO
EXEC dbo.usp_UpdateEmployeeSalary

--	Execute Session 01, 02 in Parallel
exec msdb..sp_start_job [Update Employee Salary];
exec msdb..sp_start_job [Deadlock Session];
exec msdb..sp_start_job [Deadlock Session - 2 Minutes]
exec msdb..sp_start_job [Update Employee Salary - 2 Minutes]


--exec msdb..sp_start_job [Stop SQLTrace]
--exec msdb..sp_start_job [Start Trace]

