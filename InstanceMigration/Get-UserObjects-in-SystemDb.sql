use dba
--	https://tidbytez.com/2016/10/21/how-to-identify-all-user-objects-in-the-sql-server-master-database/

Invoke-DbaQuery -SqlInstance SomeProdServerPOC -Query $query | Write-DbaDataTable -SqlInstance SomeProdServerPOCPOC -Database DBA -Table SomeProdServerPOC_SysObjects -AutoCreateTable

--use master;
--SELECT o.object_id AS ObjectId
--	,o.NAME AS ObjectName
--	,o.type_desc AS ObjectType
--	,o.create_date AS CreateDate
--	,o.modify_date AS ModifyDate
--	,SUM(st.row_count) AS RowCnt
--	,CAST(SUM(st.used_page_count) / 128.0 AS DECIMAL(36, 1)) AS DataSize_MB
--into DBA..SomeProdServerPOCPOC_SysObjects
--FROM master.sys.objects o
--LEFT JOIN master.sys.dm_db_partition_stats st ON st.object_id = o.object_id
--	AND st.index_id < 2
--GROUP BY o.object_id
--	,o.NAME
--	,o.type_desc
--	,o.create_date
--	,o.modify_date
--	,o.is_ms_shipped
--HAVING o.is_ms_shipped = 0
--	AND o.NAME <> 'sp_ssis_startup'
--	AND o.type_desc NOT LIKE '%CONSTRAINT%'
--ORDER BY CAST(SUM(st.used_page_count) / 128.0 AS DECIMAL(36, 1)) DESC
--	,RowCnt DESC

--select * from [dbo].[SomeProdServerPOC_SysObjects]
--select * from [dbo].SomeProdServerPOCPOC_SysObjects


use dba

select o.ObjectName, o.ObjectType, o.CreateDate, o.RowCnt, p.ObjectName
from [dbo].[SomeProdServerPOC_SysObjects] o
left join [dbo].SomeProdServerPOCPOC_SysObjects p
on o.ObjectName = p.ObjectName
where p.ObjectName is null
order by o.ObjectName

--truncate table [SomeProdServerPOC_SysObjects]
--drop table SomeProdServerPOCPOC_SysObjects