--------------------------------------------------------------------------------- 
--Database Backups for all databases For Previous Week 
--------------------------------------------------------------------------------- 
;with t_BkpHistOry AS 
(
	SELECT CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS SERVER
		,bs.database_name
		,bs.backup_start_date
		,bs.backup_finish_date
		,bs.expiration_date
		,CASE bs.type
			WHEN 'D'
				THEN 'Database'
			WHEN 'I'
				THEN 'Differential'
			WHEN 'L'
				THEN 'Log'
			END AS backup_type
		,bs.backup_size
		,bmf.logical_device_name
		,bmf.physical_device_name
		,bs.NAME AS backupset_name
		,bs.description
		,is_copy_only
		,ROW_NUMBER()OVER(PARTITION BY bs.database_name, bs.type ORDER BY bs.backup_start_date desc) as BackupID
	FROM msdb.dbo.backupmediafamily AS bmf
	INNER JOIN msdb.dbo.backupset AS bs ON bmf.media_set_id = bs.media_set_id
	WHERE bs.backup_start_date >= DATEADD(day,-15,getdate())
	and bmf.physical_device_name not like 'XYZMP_BACKUP%'
)
,t_HistoryLastest as
(
	SELECT	h.SERVER, d.name as dbName, h.backup_type, h.backup_start_date, h.physical_device_name
			,left(h.physical_device_name,len(h.physical_device_name)-charindex('\',REVERSE(h.physical_device_name))) as bkpPath
			,right(h.physical_device_name,3) as Extension
	FROM sys.databases d 
	left outer join
		t_BkpHistOry as h
		on h.database_name = d.name
	WHERE BackupID = 1
)
,t_BkpPaths as
(	select * 
			,ROW_NUMBER()OVER(PARTITION BY backup_type, bkpPath, Extension order by dbname) as BkpPathID
	from t_HistoryLastest h	
)
select --distinct backup_type, bkpPath, Extension
		*
from t_BkpPaths-- order by  bkpPath, dbName
where BkpPathID = 1
--where bkpPath = 'F:\Dump'
--where backup_type = 'Log'
--and bkpPath = 'G:\MSSQL15.MSSQLSERVER\Backup'
