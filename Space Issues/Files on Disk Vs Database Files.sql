select * from sys.master_files mf where mf.physical_name like 'v:\mssql\%'
--select * from sys.master_files mf where mf.physical_name like 'v:\%' and mf.physical_name not like 'v:\mssql\%'

--drop table #directoryFiles
/*
create table #directoryFiles (ID int IDENTITY, directory varchar(255), subdirectory varchar(255),depth int, [file] int);

insert #directoryFiles (subdirectory, depth, [file])
exec xp_dirtree 'v:\mssql\Data',1,1;

update #directoryFiles set directory = 'v:\mssql\Data' WHERE directory is null;

insert #directoryFiles (subdirectory, depth, [file])
exec xp_dirtree 'v:\mssql\Logs',1,1

update #directoryFiles set directory = 'v:\mssql\Logs' WHERE directory is null;

*/

;with t_dfiles as
(
	select f.directory + '\'+f.subdirectory as disk_file
	from #directoryFiles as f
	where f.[file] = 1
)
select * from t_dfiles as f where exists (select * from sys.master_files mf where mf.physical_name = f.disk_file)

