--------------------------------------------------------------------------------- 
--Database Backups for all databases For Previous Week 
--------------------------------------------------------------------------------- 
;WITH T_bkpHistory as
(
SELECT --ROW_NUMBER()over(partition by bs.database_name order by bs.backup_finish_date desc) as RowID,
		CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS SERVER
	,bs.database_name
	,bs.backup_start_date
	,bs.backup_finish_date
	,bs.expiration_date
	,CASE bs.type
		WHEN 'D'
			THEN 'Database'
		WHEN 'L'
			THEN 'Log'
		END AS backup_type
	,convert(decimal(18,3),(bs.backup_size)/1024/1024) as backup_size_MB
	,convert(decimal(18,3),(bs.backup_size)/1024/1024/1024) as backup_size_GB
	,bmf.logical_device_name
	,bmf.physical_device_name
	,bs.NAME AS backupset_name
	,bs.description
	,first_lsn
	,last_lsn
	,checkpoint_lsn
	,database_backup_lsn
	,is_copy_only
	,is_snapshot
	--bs.* --bmf.*
FROM msdb.dbo.backupmediafamily AS bmf
INNER JOIN msdb.dbo.backupset AS bs ON bmf.media_set_id = bs.media_set_id
WHERE bs.backup_start_date >= dateadd(day,-2,(select max(bsi.backup_start_date) FROM msdb.dbo.backupmediafamily AS bmfi INNER JOIN msdb.dbo.backupset AS bsi ON bmfi.media_set_id = bsi.media_set_id where bsi.database_name = bs.database_name and bsi.type = 'D'))
AND database_name = 'Facebook'

)
select * 
from T_bkpHistory
ORDER BY backup_start_date