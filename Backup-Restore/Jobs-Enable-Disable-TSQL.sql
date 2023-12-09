USE DBA
GO

/*	

*/

select	'
EXEC msdb.dbo.sp_update_job  @job_name = N'''+j.name+''', @enabled = 0 ;  
GO
'
from msdb..sysjobs_view j 
where j.name in ('job1','job2')
and j.enabled = 1


select	--j.name, j.enabled, j.description, c.name
		'
EXEC msdb.dbo.sp_update_job  @job_name = N'''+j.name+''', @enabled = 0 ;  
GO
'
from msdb..sysjobs_view j join msdb..syscategories c
on j.category_id = c.category_id
where c.name like '%Repl%'
and j.enabled = 1
and c.name in ('REPL-LogReader','REPL-Distribution')

select	cl.DatabaseName, cl.CommandType, cl.StartTime, cl.EndTime,
		DATEDIFF(minute,cl.startTime, cl.EndTime) as Time_Minutes, cl.Command
from	dbo.CommandLog cl
where	cl.CommandType in ('BACKUP_DATABASE')
	and	cl.StartTime >= DATEADD(hh,-12,getdate())


select	*
from	sys.master_files mf
where	db_name(mf.database_id) in ('FacebookFiltered')

exec sp_helpdb 'FacebookLondon'

--------------------------------------------------------------------------------- 
--Database Backups for all databases For Previous Week 
--------------------------------------------------------------------------------- 
SELECT TOP 4 CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS SERVER
	,bs.database_name
	,bs.backup_start_date
	,bs.backup_finish_date
	,bs.expiration_date
	,CASE bs.type
		WHEN 'D'
			THEN 'Database'
		WHEN 'L'
			THEN 'Log'
		WHEN 'I'
			THEN 'Diff'
		END AS backup_type
	,bs.backup_size
	,bmf.logical_device_name
	,bmf.physical_device_name
	,bs.NAME AS backupset_name
	,bs.description
	,first_lsn
	,last_lsn
	,checkpoint_lsn
	,database_backup_lsn
	,is_copy_only
FROM msdb.dbo.backupmediafamily AS bmf
INNER JOIN msdb.dbo.backupset AS bs ON bmf.media_set_id = bs.media_set_id
WHERE database_name in ('FacebookLondon','StatingFiltered','FacebookFiltered','FacebookFiltered')
AND bs.type = 'Log'
ORDER BY bs.backup_finish_date DESC