/*	1) Execute sp_whoIsActive and store result in Excel	*/
$instance = 'SqlpDB01';
$excelPath = "C:\Temp\$instance.xlsx";
$sqlQuery = @" 
exec sp_whoIsActive @get_plans=1, @get_full_inner_text=1, 
                    @get_transaction_info=1, @get_task_info=2, 
                    @get_locks=1, @get_avg_time=1, @get_additional_info=1,
                    @find_block_leaders=1
"@;

Invoke-Sqlcmd -ServerInstance $instance -Query $sqlQuery | Export-Excel $excelPath -Show;

/*	2) Execute sp_whoIsActive and store result in Excel	using ADO.NET Method*/
$instance = 'SqlpDB01'
$excelPath = "C:\Temp\$instance.xlsx";
$sqlQuery = @" 
exec sp_whoIsActive @get_plans=1, @get_full_inner_text=1, 
                    @get_transaction_info=1, @get_task_info=2, 
                    @get_locks=1, @get_avg_time=1, @get_additional_info=1,
                    @find_block_leaders=1
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
