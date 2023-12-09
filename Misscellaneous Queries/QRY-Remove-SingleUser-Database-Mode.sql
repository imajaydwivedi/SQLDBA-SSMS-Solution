/*	Get database out of Single User mode 
	alter database StackOverflow2013 set single_user with rollback immediate;
	alter database StackOverflow2013 set multi_user with rollback immediate;
*/

use master;
go
set nocount on;
set deadlock_priority 10;

declare @db_name varchar(100);
set @db_name = 'StackOverflow2013';

declare @sqlAlterDatabase nvarchar(2000);
declare @sqlKillSession nvarchar(2000);

set @sqlAlterDatabase = 'ALTER DATABASE ['+@db_name+'] SET MULTI_USER WITH rollback immediate;';

-- Keep looping while database is in SingleUser mode
while exists (select 1/0 from sys.databases where name = @db_name and user_access_desc = 'SINGLE_USER')
begin
	declare cur_ssns cursor local forward_only for 
		select distinct 'kill '+convert(varchar,tl.request_session_id)+'
	'
	from sys.dm_tran_locks tl
	where tl.resource_database_id = db_id(@db_name)
	and tl.request_session_id <> @@SPID

	open cur_ssns
	fetch next from cur_ssns into @sqlKillSession
	while @@FETCH_STATUS = 0
	begin
		begin try
			exec (@sqlKillSession);
			exec (@sqlAlterDatabase);
		end try
		begin catch
			print error_message()
		end catch
		fetch next from cur_ssns into @sqlKillSession
	end
	close cur_ssns
	deallocate cur_ssns
end
go
