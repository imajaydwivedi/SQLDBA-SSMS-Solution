use ScratchPad
go

select *
from dbo.employee
go

-- Grant SELECT on specific columns to offshore
GRANT SELECT (emp_id, name, dob) ON dbo.employee TO offshore;
-- Deny SELECT on restricted columns
DENY SELECT (address, salary) ON dbo.employee TO offshore;
go

use ScratchPad
go

print 'I am => '+convert(varchar,SUSER_NAME());

select *
from dbo.employee
go          

/*
create table dbo.employee
(	emp_id int not null,
	name varchar(80) not null,
	dob date not null,
	salary bigint not null,
	address varchar(250) not null,
	
	index cx_employee unique clustered (emp_id)
)
go

truncate table dbo.employee;
go

insert dbo.employee (emp_id, name, dob, salary, address)
select *
from (values (1,'Ajay','1989-08-17',5000000,'Nagpur'),
		(2,'Gaurav','1988-06-08',3800000,'Hyderabad')
	) emp_data (emp_id, name, dob, salary, address);
go
*/