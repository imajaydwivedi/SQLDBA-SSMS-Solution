BACKUP DATABASE [contsoSQLInventory] 
	TO DISK = N'G:\MSSQL15.MSSQLSERVER\SQL2016_Backup\contsoSQLInventory\FULL\contsoSQLInventory_FULL_20190206_225446.bak' 
	WITH NO_CHECKSUM, COMPRESSION;


RESTORE DATABASE [contsoSQLInventory_Ajay] FROM  DISK = N'G:\MSSQL15.MSSQLSERVER\SQL2016_Backup\contsoSQLInventory\FULL\contsoSQLInventory_FULL_20190206_225446.bak' 
    WITH RECOVERY
         ,STATS = 3
		 ,MOVE N'contsoSQLInventory' TO N'F:\MSSQL15.MSSQLSERVER\SQL2016_Data\contsoSQLInventory_Ajay.mdf'
		 ,MOVE N'contsoSQLInventory_log' TO N'F:\MSSQL15.MSSQLSERVER\SQL2016_Log\contsoSQLInventory_Ajay_log.ldf'

GO


RESTORE DATABASE [contsoSQLInventory_Dev] FROM  DISK = 'G:\MSSQL15.MSSQLSERVER\SQL2016_Backup\contsoSQLInventory_Distributor\FULL\contsoSQLInventory_Distributor_FULL_20190214_034700.bak' 
    WITH RECOVERY
         ,STATS = 3
         ,REPLACE
		 ,MOVE N'contsoSQLInventory' TO N'F:\MSSQL15.MSSQLSERVER\SQL2016_Data\contsoSQLInventory_Dev.mdf'
		 ,MOVE N'contsoSQLInventory_log' TO N'F:\MSSQL15.MSSQLSERVER\SQL2016_Data\contsoSQLInventory_Dev_log.ldf'
GO


select top 1 cl.DatabaseName, cl.Command, cl.StartTime 
from DBA.dbo.CommandLog as cl 
where cl.CommandType = 'BACKUP_DATABASE' 
order by cl.StartTime desc
