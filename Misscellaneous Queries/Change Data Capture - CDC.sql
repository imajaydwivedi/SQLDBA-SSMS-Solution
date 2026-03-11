/* ~~~~~~~~~~ CHANGE DATA CAPTURE (CDC) on Availability Group ~~~~~~~ */
-- Youtube - https://youtu.be/E0KpqD3SM1U?si=V2HM9tQypZA7eqmm

-- Step 1: Create a database for the CDC demo
create database CDCDemo;
go
ALTER DATABASE CDCDemo SET RECOVERY FULL WITH NO_WAIT;
GO
backup database CDCDemo to disk = N'NUL';
go

-- Step 2: Add database to Availability Group

-- Step 3: Enable CDC at the database level
	-- Switch to the new database
use CDCDemo
go
exec sys.sp_cdc_enable_db;
go

-- Check CDC is enable
select is_cdc_enabled, * from sys.databases;

-- Step 4: Create a table to track changes
create table dbo.Employees (
	EmployeeID int identity(1,1) primary key,
	FirstName varchar(50),
	LastName varchar(50),
	Position varchar(50),
	Salary decimal(10,2)
);
go

-- Step 5: Enable CDC for the Employees table
exec sys.sp_cdc_enable_table
	@source_schema = 'dbo',
	@source_name = 'Employees',
	@role_name = NULL;
go

-- Step 6: Insert sample data into the table
insert into dbo.Employees (FirstName, LastName, Position, Salary)
values
('Saanvi', 'Dwivedi', 'Developer', 20000),
('Priti', 'Sharma', 'Engineer', 30000),
('Ajay', 'Dwivedi', 'Sr Engineer', 50000),
('Anant', 'Dwivedi', 'Analyst', 15000);
go

select * from Employees;

-- Step 7: Update some records to generate changes
update Employees
set Salary = 60000
where FirstName = 'Ajay';

update Employees
set Position = 'Sr Analyst'
where FirstName = 'Anant';

-- Step 8: View change data in CDC tables
select * from Employees where EmployeeID = 1002;
select * from cdc.dbo_Employees_CT where EmployeeID = 1002;

delete from Employees
where EmployeeID = 1;
go

-- Step 9: Validate [cdc.CDCDemo_capture] & [cdc.CDCDemo_cleanup] on primary replica
select	j_exp.cdc_job_name, j_exp.job_type, jv.job_id, jv.job_category, 
		[job_exists] = case when jv.job_id is not null then cast(1 as bit) else cast(0 as bit) end,
		[re_create_job] = case when j_exp.job_type = 'capture' then 'use '+quotename(d.name)+'; EXEC sys.sp_cdc_add_job @job_type = N''capture'';'
								else 'use '+quotename(d.name)+'; EXEC sys.sp_cdc_add_job @job_type = N''cleanup'';'
								end
from master.sys.databases d
outer apply (values ('capture', 'cdc.'+d.name+'_capture'),('cleanup','cdc.'+d.name+'_cleanup')) j_exp(job_type, cdc_job_name)
outer apply (	select jv.job_id, jc.name as job_category
				from msdb.dbo.sysjobs_view jv 
				left join msdb.dbo.syscategories jc
					on jc.category_id = jv.category_id
				where jv.name = j_exp.cdc_job_name
			) jv
where d.is_cdc_enabled = 1
go

-- Step 10: Failover to other ag node. Check if cdc jobs exists?

-- Step 11: If cdc jobs do not exist on new primary, then create them using below tsql
USE CDCDemo;
GO
EXEC sys.sp_cdc_add_job @job_type = N'capture';
EXEC sys.sp_cdc_add_job @job_type = N'cleanup';
go

-- Step 12: Validate if changes are synching even if jobs are recreated with new job_ids on all replicas.
:CONNECT AgHost-1A -C
select @@servername, * from CDCDemo.cdc.dbo_Employees_CT;
go

:CONNECT AgHost-1B -C
select @@servername, * from CDCDemo.cdc.dbo_Employees_CT;
go

-- Automation: Automatically create CDC Jobs if missing
declare @sql_create_job nvarchar(max);
declare cursor_cdc_jobs cursor local fast_forward for 
	select	--j_exp.cdc_job_name, j_exp.job_type, jv.job_id, jv.job_category, [job_exists],
			[re_create_job] = case when j_exp.job_type = 'capture' then 'use '+quotename(d.name)+'; EXEC sys.sp_cdc_add_job @job_type = N''capture'';'
									else 'use '+quotename(d.name)+'; EXEC sys.sp_cdc_add_job @job_type = N''cleanup'';'
									end
	from master.sys.databases d
	outer apply (values ('capture', 'cdc.'+d.name+'_capture'),('cleanup','cdc.'+d.name+'_cleanup')) j_exp(job_type, cdc_job_name)
	outer apply (	select jv.job_id, jc.name as job_category
					from msdb.dbo.sysjobs_view jv 
					left join msdb.dbo.syscategories jc
						on jc.category_id = jv.category_id
					where jv.name = j_exp.cdc_job_name
				) jv
	outer apply (select [job_exists] = case when jv.job_id is not null then cast(1 as bit) else cast(0 as bit) end) jv_exists
	where d.is_cdc_enabled = 1
	--and [job_exists] = 0;

open cursor_cdc_jobs;
fetch next from cursor_cdc_jobs into @sql_create_job;

while @@fetch_status = 0
begin
	--print @sql_create_job;
	exec sp_executesql @sql_create_job;
	fetch next from cursor_cdc_jobs into @sql_create_job;
end

close cursor_cdc_jobs;
deallocate cursor_cdc_jobs;
go


/* Questions
1. What happens if cdc jobs are missing on new primary, and data is inserted?
Answer => Healthy. TLog is NOT truncated untill the data is consumed by REPL jobs (including cdc jobs).

-- insert record while jobs do not exist
insert into dbo.Employees (FirstName, LastName, Position, Salary)
values ('Sanjay', 'Chopra', 'Sr Developer', 30000);

select * from cdc.dbo_Employees_CT;

-- create jobs now

2. Does automation job name follow the naming convention, or are they truncated in case of long DB names?
Answer => Healthy. I tested with database name of 56 characters long
	db_name -> [Why People Think of a Very Large Database Name Like This].

3. Does re-run of the sys.sp_cdc_add_job cause any issue?
Answer => Healthy. No error is thrown if the jobs already exist.

4. With this soluation, are jobs on different servers created with same Job_ID? If yes, does it cause issues post failover?
Answer => No. Job_ID is auto generated. So will be different on all replicas.

Aspect 01: Failover, but NO SQLService restart
In this case, we need to start the jobs using msdb.dbo.sp_start_job.

Aspect 02: Failover with SQLService restart
In this case, no manual action is need since CDC jobs are configured to start with agent.


Msg 22911, Level 16, State 1, Procedure sys.sp_MScdc_tranrepl_check, Line 21 [Batch Start Line 90]
The capture job cannot be used by Change Data Capture to extract changes from the log when transactional replication is also enabled on the same database. When Change Data Capture and transactional replication are both enabled on a database, use the logreader agent to extract the log changes.

*/

