use tempdb
go

/*
--drop table dbo.dba_log_table;
create table dbo.dba_log_table (
	proc_name sysname, 
	step_name varchar(255), 
	collection_time datetime2,
	id int identity(1,1) not null,
	index ci_dba_log_table clustered (collection_time),
	index proc_name (proc_name)
);
*/
go

create or alter procedure usp_GestRollback 
as
begin
	set xact_abort on;

	insert dba_log_table (proc_name, step_name, collection_time)
	select 'usp_GestRollback','Start',getdate();

	begin try
		declare @_step_id int = 1;
		declare @_total_steps int = 5;

		begin tran start_proc
			while (@_step_id <= @_total_steps)
			begin
				select [@_step_id] = @_step_id;

				insert dba_log_table (proc_name, step_name, collection_time)
				select 'usp_GestRollback',convert(varchar,@_step_id),getdate();

				--waitfor delay '00:00:05'
				if @_step_id = 3
					select 1/0;

				set @_step_id += 1;
			end
		commit tran start_proc
	end try
	begin catch
		select ERROR_MESSAGE();

		rollback tran start_proc;
	end catch

	insert dba_log_table (proc_name, step_name, collection_time)
	select 'usp_GestRollback','end',getdate();
end
go

--  rollback tran

exec usp_GestRollback
go

--select @@TRANCOUNT

