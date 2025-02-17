SELECT rs.[restore_history_id]
 ,rs.[restore_date]
 ,rs.[destination_database_name]
 ,bmf.physical_device_name
 ,rs.[user_name]
 ,rs.[backup_set_id]
 ,CASE rs.[restore_type]
 WHEN 'D' THEN 'Database'
 WHEN 'I' THEN 'Differential'
 WHEN 'L' THEN 'Log'
 WHEN 'F' THEN 'File'
 WHEN 'G' THEN 'Filegroup'
 WHEN 'V' THEN 'Verifyonlyl'
 END AS RestoreType
 ,rs.[replace]
 ,rs.[recovery]
 ,rs.[restart]
 ,rs.[stop_at]
 ,rs.[device_count]
 ,rs.[stop_at_mark_name]
 ,rs.[stop_before]
 FROM [msdb].[dbo].[restorehistory] rs
 inner join [msdb].[dbo].[backupset] bs
 on rs.backup_set_id = bs.backup_set_id
 INNER JOIN msdb.dbo.backupmediafamily bmf 
 ON bs.media_set_id = bmf.media_set_id
 where 1=1
 --and rs.[destination_database_name] = 'Washington'
 order by rs.[restore_date] desc
 GO