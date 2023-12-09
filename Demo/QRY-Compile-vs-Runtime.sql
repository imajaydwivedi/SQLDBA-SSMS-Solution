use tempdb
go

create table dbo.person (id int identity not null, fullname varchar(200))
go

/* Session 01

alter table dbo.person add city varchar(200);

select fullname, city
from dbo.person;

*/

select *
from employee e
left join address a 
	on a.empid = a.empid
	and a.city = 'Delhi'


All employee 
	> Delhi - All address details
	> Non-Delhi -- All blank in address


select *
from employee e
left join address a 
	on a.empid = a.empid
where a.city = 'Delhi'

Delhi People