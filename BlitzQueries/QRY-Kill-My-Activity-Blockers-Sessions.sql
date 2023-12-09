/*	Kill blockers of my activity */
declare @spid int;
declare @sql nvarchar(2000);
declare @my_session_id int = 530;

while exists (select 1 from sys.dm_exec_requests r where r.session_id = @my_session_id and blocking_session_id > 0 )
begin
	select @spid = blocking_session_id
	from sys.dm_exec_requests r
	where r.session_id = @my_session_id
	and blocking_session_id > 0;

	if @spid > 0
	begin
		set @sql = 'kill '+convert(varchar,@spid);
		begin try
			exec (@sql)
		end try
		begin catch
			print error_message();
		end catch
	end
end
go