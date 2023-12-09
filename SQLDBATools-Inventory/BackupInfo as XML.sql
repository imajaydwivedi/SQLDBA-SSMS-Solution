;with t_servers as 
(
	select distinct InstanceName, BatchNumber
	from [dbo].[DatabaseBackup]
	where BatchNumber = (select max(i.BatchNumber) from [dbo].[DatabaseBackup] i)
)
select	InstanceName as [@Name]
		,(
			select DatabaseName as [@Name], DatabaseCreationDate as [@DatabaseCreationDate], b.RecoveryModel as [@RecoveryModel] , 
					CollectionTime as [@CollectionTime] ,d.SizeMB as [@SizeMB]
					,LastFullBackupDate as [LastFullBackupDate], LastDifferentialBackupDate as [LastDifferentialBackupDate], LastLogBackupDate as [LastLogBackupDate]					
			from [dbo].[DatabaseBackup] b inner join Info.[Database] as d on d.SqlInstance = b.InstanceName
			where s.InstanceName = b.InstanceName and s.BatchNumber = b.BatchNumber
			for xml path('Database'), root('Databases'),type
		)		
from	t_servers as s
for xml path('SQLInstance'),root('BackupInfo')
go


--use SQLDBATools
--go

--select top 10 * from Info.[Database]

--select * from INFORMATION_SCHEMA.TABLES