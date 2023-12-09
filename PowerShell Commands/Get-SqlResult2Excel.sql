$instance = 'MyDbServerName';
$excelPath = "C:\Temp\DataFileInfo__$instance.xlsx";
$sqlQuery = @" 
EXEC tempdb..[usp_AnalyzeSpaceCapacity] @getLogInfo = 1;
/*
EXEC sp_msForEachDB '
USE [?];
SELECT	DBName, O.*
FROM ( VALUES (DB_NAME()) ) DBs (DBName)
LEFT JOIN
	(
		SELECT	OBJECT_NAME(ps.object_id) as TableName,
				i.name as IndexName,
				ps.index_type_desc,
				ps.page_count,
				ps.avg_fragmentation_in_percent,
				ps.forwarded_record_count
		FROM	sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, ''DETAILED'') AS ps
		INNER JOIN sys.indexes AS i
			ON ps.OBJECT_ID = i.OBJECT_ID  
			AND ps.index_id = i.index_id
		WHERE forwarded_record_count > 0
	) AS O
	ON	1 = 1
'
*/
--exec sp_whoIsActive --@get_full_inner_text=1,@get_transaction_info=1, @get_task_info=2,@get_locks=1, @get_avg_time=1, @get_additional_info=1,@find_block_leaders=1,@get_plans=1
"@;

$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server=$instance;Database=master;Integrated Security=True"
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.CommandText = $sqlQuery
$SqlCmd.Connection = $SqlConnection
$SqlCmd.CommandTimeout = 0
$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
$SqlAdapter.SelectCommand = $SqlCmd
$DataSet = New-Object System.Data.DataSet;
$SqlAdapter.Fill($DataSet);
$SqlConnection.Close();

$DataSet.Tables[0] | Export-Excel $excelPath -Show;