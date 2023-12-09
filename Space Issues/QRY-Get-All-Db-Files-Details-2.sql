use master;

set quoted_identifier off;

IF OBJECT_ID('tempdb..#database_files_temp') IS NOT NULL
	DROP TABLE #database_files_temp;
CREATE TABLE #database_files_temp
(
	[ComputerName] [sql_variant] NULL,
	[db_name] [nvarchar](128) NULL,
	[type_desc] [nvarchar](60) NULL,
	[file_group] [sysname] NULL,
	[name] [sysname] NOT NULL,
	[physical_name] [nvarchar](260) NOT NULL,
	[size_GB] [decimal](20, 2) NULL,
	[max_size] [int] NOT NULL,
	[growth] [int] NOT NULL,
	[SpaceUsed_gb] [decimal](20, 2) NULL,
	[FreeSpace_GB] [decimal](20, 2) NULL,
	[Used_Percentage] [decimal](20, 2) NULL,
	[log_reuse_wait_desc] [nvarchar](60) NULL
);

INSERT #database_files_temp
exec sp_MSforeachdb "
use [?] ;
--if exists (select * from sys.databases where name = '?' and replica_id is null)
--begin
	--	Find used/free space in Database Files
	select SERVERPROPERTY('MachineName') AS ComputerName, --SERVERPROPERTY ( 'ComputerNamePhysicalNetBIOS' ) as PhysicalName, @@servername as sql_instance, ,
					DB_NAME() AS [db_name], f.type_desc, fg.name as file_group, f.name, f.physical_name, CONVERT(DECIMAL(20,2),(f.size*8.0)/1024/1024) as size_GB, f.max_size, f.growth, 
					CONVERT(DECIMAL(20,2),CAST(FILEPROPERTY(f.name, 'SpaceUsed') as BIGINT)/128.0/1024) AS SpaceUsed_gb
					,CONVERT(DECIMAL(20,2),(size/128.0 -CAST(FILEPROPERTY(f.name,'SpaceUsed') AS INT)/128.0)/1024) AS FreeSpace_GB
					,cast((FILEPROPERTY(f.name,'SpaceUsed')*100.0)/size as decimal(20,2)) as Used_Percentage
					,CASE WHEN f.type_desc = 'LOG' THEN (select d.log_reuse_wait_desc from sys.databases as d where d.name = DB_NAME()) ELSE NULL END as log_reuse_wait_desc
	from sys.database_files f left join sys.filegroups fg on fg.data_space_id = f.data_space_id
	order by FreeSpace_GB desc;
--end
";

SELECT *
FROM #database_files_temp;
