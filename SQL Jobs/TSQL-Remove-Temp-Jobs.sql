use DBA
go

declare @_job_name nvarchar(500);
declare @_row_affected int = -1;

declare @pattern varchar(max);
set @pattern = '%[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]-[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]';

if OBJECT_ID('dbo.jobs_2_delete') is null
    exec ('create table dbo.jobs_2_delete (id int identity(1,1) not null, job_name nvarchar(500) not null, job_id uniqueidentifier not null);');
else
	truncate table jobs_2_delete;

if not exists (select 1/0 from dbo.jobs_2_delete)
begin
    insert dbo.jobs_2_delete (job_name, job_id)
    select name, job_id from msdb.dbo.sysjobs (READPAST)
        where 1=1
        and name like '% FUTURES AUTO PROCESS SETTLEMENT_%'
		and date_created < DATEADD(hour, -4, getdate())
		and name like @pattern;

	set @_row_affected = @@ROWCOUNT;
end

print convert(varchar,@_row_affected)+' temp jobs to be removed.';

delete from dl from msdb.dbo.sysdownloadlist dl join dbo.jobs_2_delete j on dl.object_id = j.job_id;
delete from t from msdb.dbo.systaskids t join dbo.jobs_2_delete j on t.job_id = j.job_id;
delete from t from msdb.dbo.sysdbmaintplan_jobs t join dbo.jobs_2_delete j on t.job_id = j.job_id;
delete from t from msdb.dbo.sysjobschedules t join dbo.jobs_2_delete j on t.job_id = j.job_id;
delete from t from msdb.dbo.sysjobservers t join dbo.jobs_2_delete j on t.job_id = j.job_id;
delete from t from msdb.dbo.sysjobsteps t join dbo.jobs_2_delete j on t.job_id = j.job_id;
delete from t from msdb.dbo.sysjobs t join dbo.jobs_2_delete j on t.job_id = j.job_id;
delete from t from msdb.dbo.sysjobhistory t join dbo.jobs_2_delete j on t.job_id = j.job_id;

print 'Jobs deleted successfully.'