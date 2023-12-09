/* Move Data or Log files to Another location/Drive/Folder */

set nocount on;

declare @data_file_path varchar(255) = 'G:\Data\';
declare @log_file_path varchar(255) = 'G:\Log\';

SELECT [-- Change File Path MetaData --] = 
		'-- Move '+quotename(convert(varchar,convert(numeric(20,2),(size*8.0/1024/1024))))+' gb file. '+quotename(db_name(f.database_id))+'.'+QUOTENAME(f.physical_name)+'
ALTER DATABASE '+quotename(db_name(f.database_id))+' MODIFY FILE (NAME = [' + f.name + '],'
		+ ' FILENAME = '''+
						(case when f.type_desc = 'LOG' 
								then @log_file_path 
								else @data_file_path end)
						+ RIGHT(f.physical_name,CHARINDEX('\',REVERSE(f.physical_name))-1)
		+ ''');'
FROM sys.master_files f
WHERE f.physical_name like 'c:\%'
and db_name(f.database_id) not in ('master','model','msdb')
go

SELECT [-- Rollback for File Path Change --] = 
		'ALTER DATABASE '+quotename(db_name(f.database_id))+' MODIFY FILE (NAME = [' + f.name + '],'
		+ ' FILENAME = '''+f.physical_name+ ''');'
FROM sys.master_files f
WHERE f.physical_name like 'c:\%'
and db_name(f.database_id) not in ('master','model','msdb')
go