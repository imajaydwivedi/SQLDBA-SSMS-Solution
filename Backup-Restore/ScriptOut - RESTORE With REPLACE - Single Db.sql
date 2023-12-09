SET NOCOUNT ON;

declare @p_dbName varchar(100)
set @p_dbName = 'Facebook';

declare @sqlRestoreText varchar(max)
set @sqlRestoreText = '
RESTORE DATABASE '+QUOTENAME(@p_dbName)+' FROM  DISK = N''Your-Backup-File-Path-in-Here''
    WITH RECOVERY
         ,STATS = 3
         ,REPLACE
';

select @sqlRestoreText += --name, physical_name,
'		 ,MOVE N'''+name+''' TO N'''+physical_name+'''
'
from sys.master_files as mf 
where mf.database_id = DB_ID(@p_dbName);

SET @sqlRestoreText += '
GO'

PRINT @sqlRestoreText
