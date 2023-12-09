--	https://social.msdn.microsoft.com/Forums/sqlserver/en-US/c14ac5be-3489-40b4-a4ef-7be39428ba57/database-creation-date-after-restore?forum=sqlgetstarted
--	Database "Creation Date" after restore with OverWrite

/*	Create Date of Database */
SELECT	@@SERVERNAME as [@@SERVERNAME] ,GETDATE() AS [GETDATE()]
		,d.name ,d.create_date
FROM	sys.databases as d
WHERE	d.name = 'LSTesting';

--	Check Restore History
SELECT	top 5 [rs].[destination_database_name], 
		[rs].[restore_date], 
		[bs].[backup_start_date], 
		[bs].[backup_finish_date], 
		[bs].[database_name] as [source_database_name], 
		[bmf].[physical_device_name] as [backup_file_used_for_restore] 
		,[BackupType] = case bs.type when 'D' then 'Full' when 'L' then 'TLog' when 'G' then 'Diff' else NULL END
FROM msdb..restorehistory rs 
INNER JOIN msdb..backupset bs 
ON [rs].[backup_set_id] = [bs].[backup_set_id] 
INNER JOIN msdb..backupmediafamily bmf 
ON [bs].[media_set_id] = [bmf].[media_set_id] 
WHERE destination_database_name LIKE 'LSTesting%'
ORDER BY [rs].[restore_date] DESC

--if [restore_date] of full backup is less than [restore_date] of TLog bacukup

