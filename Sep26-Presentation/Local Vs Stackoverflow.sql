/* Local */
set statistics io on;
set statistics time on;
select * from dbo.Users u
	where u.DisplayName = 'Ajay Dwivedi' and Location = 'Delhi, India'

/* Stackoverflow */
set statistics io on;
set statistics time on;
select * from dbo.Users u
	where u.DisplayName = 'Ajay Dwivedi' 
    and Location = 'Bangalore, Karnataka, India'