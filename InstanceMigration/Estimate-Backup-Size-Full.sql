 
;WITH T_History as
(
	SELECT bs.database_name as dbName		
		,cast(max(bs.backup_size) / 1024 /1024 as decimal(20,2)) as backup_size_MB
		,cast(max(bs.compressed_backup_size) / 1024 /1024 as decimal(20,2)) as compressed_backup_size_MB
	FROM msdb.dbo.backupmediafamily AS bmf
	INNER JOIN msdb.dbo.backupset AS bs ON bmf.media_set_id = bs.media_set_id
	WHERE bs.type in ('D')
	GROUP BY database_name
)
,t_filtered as (
	select d.name as dbName, backup_size_MB, compressed_backup_size_MB
	from sys.databases d
	left join T_History h
	on h.dbName = d.name
)
select 'Full-Backup' as BackupType, sum(f.backup_size_MB)/1024 as backup_size_GB, sum(f.compressed_backup_size_MB)/1024 as compressed_backup_size_GB  
from t_filtered f;
go


;WITH T_History as
(
	SELECT bs.database_name as dbName		
		,cast(max(bs.backup_size) / 1024 /1024 as decimal(20,2)) as backup_size_MB
		,cast(max(bs.compressed_backup_size) / 1024 /1024 as decimal(20,2)) as compressed_backup_size_MB
	FROM msdb.dbo.backupmediafamily AS bmf
	INNER JOIN msdb.dbo.backupset AS bs ON bmf.media_set_id = bs.media_set_id
	WHERE bs.type in ('L')
	AND bs.backup_finish_date >= DATEADD(DAY,-1,GETDATE())
	GROUP BY database_name
)
,t_filtered as (
	select d.name as dbName, backup_size_MB, compressed_backup_size_MB
	from sys.databases d
	left join T_History h
	on h.dbName = d.name
)
select 'Log-Backup' as BackupType, sum(f.backup_size_MB)/1024 as backup_size_GB, sum(f.compressed_backup_size_MB)/1024 as compressed_backup_size_GB  
from t_filtered f;
go