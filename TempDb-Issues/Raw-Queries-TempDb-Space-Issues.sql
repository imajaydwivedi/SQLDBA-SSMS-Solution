use tempdb
go

/*	https://dba.stackexchange.com/questions/13911/how-to-find-the-sql-statements-that-caused-tempdb-growth
*/
SELECT
  sys.dm_exec_sessions.session_id AS [SESSION ID]
  ,DB_NAME(database_id) AS [DATABASE Name]
  ,HOST_NAME AS [System Name]
  ,program_name AS [Program Name]
  ,login_name AS [USER Name]
  ,status
  ,cpu_time AS [CPU TIME (in milisec)]
  ,total_scheduled_time AS [Total Scheduled TIME (in milisec)]
  ,total_elapsed_time AS    [Elapsed TIME (in milisec)]
  ,(memory_usage * 8)      AS [Memory USAGE (in KB)]
  ,(user_objects_alloc_page_count * 8) AS [SPACE Allocated FOR USER Objects (in KB)]
  ,(user_objects_dealloc_page_count * 8) AS [SPACE Deallocated FOR USER Objects (in KB)]
  ,(internal_objects_alloc_page_count * 8) AS [SPACE Allocated FOR Internal Objects (in KB)]
  ,(internal_objects_dealloc_page_count * 8) AS [SPACE Deallocated FOR Internal Objects (in KB)]
  ,CASE is_user_process
             WHEN 1      THEN 'user session'
             WHEN 0      THEN 'system session'
  END         AS [SESSION Type], row_count AS [ROW COUNT]
FROM 
  sys.dm_db_session_space_usage
INNER join
  sys.dm_exec_sessions
ON  sys.dm_db_session_space_usage.session_id = sys.dm_exec_sessions.session_id
go


/*
	https://social.msdn.microsoft.com/Forums/sqlserver/en-US/b875d27f-0da9-44c8-a53c-95151a7a1983/catch-what-is-causing-tempdb-to-grow?forum=sqldatabaseengine

Reasons for tempdb to grow:
	1.Any sorting that requires more memory than has been allocated to SQL Server will be forced to do its work in tempdb;  
	2.DBCC CheckDB('any database') will perform its work in tempdb -- on larger databases, this can consume quite a bit of space;  
	3.DBCC DBREINDEX or similar DBCC commands with 'Sort in tempdb' option set will also potentially fill up tempdb;  
	4.large resultsets involving unions, order by / group by, cartesian joins, outer joins, cursors, temp tables, table variables, and hashing can often require help from tempdb;  
	5.any transactions left uncommitted and not rolled back can leave objects orphaned in tempdb;  
	6.use of an ODBC DSN with the option 'create temporary stored procedures' set can leave objects there for the life of the connection.
*/
use tempdb
go

SELECT	'sys.dm_db_file_space_usage' as DMV, getdate() as currentTime, SUM (user_object_reserved_page_count)*8 as usr_obj_kb,
		SUM (internal_object_reserved_page_count)*8 as internal_obj_kb,
		SUM (version_store_reserved_page_count)*8 as version_store_kb,
		SUM (version_store_reserved_page_count)*8/1024/1024 as version_store_gb,
		SUM (unallocated_extent_page_count)*8 as freespace_kb,
		SUM (mixed_extent_page_count)*8 as mixedextent_kb
FROM sys.dm_db_file_space_usage;

SELECT top 5 'sys.dm_db_session_space_usage' as DMV, getdate() as currentTime, * 
FROM sys.dm_db_session_space_usage 
ORDER BY (user_objects_alloc_page_count + internal_objects_alloc_page_count) DESC;

SELECT top 5 'sys.dm_db_task_space_usage' as DMV, getdate() as currentTime, * 
FROM sys.dm_db_task_space_usage
ORDER BY (user_objects_alloc_page_count + internal_objects_alloc_page_count) DESC
