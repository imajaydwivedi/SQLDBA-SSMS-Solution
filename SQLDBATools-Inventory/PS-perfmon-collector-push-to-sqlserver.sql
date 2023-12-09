Import-Module dbatools;
$collector_root_directory = 'D:\\MSSQL15.MSSQLSERVER\\MSSQL\Perfmon';
$data_collector_set_name = 'DBA';
$dsn = 'LocalSqlServer';
$DBAInventory = 'MSI';

$data_collector_template_path = �$collector_root_directory\DBA_PerfMon_NonSQL_Collector_Template.xml�;
$log_file_path = "$collector_root_directory\$($env:COMPUTERNAME)__"

$tsql_last_log_file_imported = @"
if OBJECT_ID('DBA.dbo.DisplayToID') is null
	select CAST(NULL AS varchar(1024)) AS DisplayString;
else
	select a.DisplayString
	from (
			select top 1 DisplayString
			from DBA.dbo.DisplayToID --full outer join (select CAST(NULL AS varchar(1024)) AS D) as D on 1 = 1 
			where DisplayString like 'D:\\MSSQL15.MSSQLSERVER\\MSSQL\Perfmon%'
			order by LogStopTime desc
		 ) as a
	full outer join (select CAST(NULL AS varchar(1024)) AS DisplayString) as d on 1 = 1;
"@
$last_log_file_imported = Invoke-DbaQuery -SqlInstance $DBAInventory -Query $tsql_last_log_file_imported | Select-Object -ExpandProperty DisplayString;

$current_collector_state = logman -n $data_collector_set_name;
$location_line = $current_collector_state | Where-Object {$_ -like 'Output Location:*'}
$status_line = $current_collector_state | Where-Object {$_ -like 'Status:*'}
$current_log_file = $location_line.Replace("Output Location:",'').trim();
$current_log_file_status = $status_line.Replace("Status:",'').trim();

$perfmonfiles = Get-ChildItem -Path $collector_root_directory  -Filter *.blg |
                    Where-Object {$_.FullName -gt $last_log_file_imported -or $last_log_file_imported -eq $null -or [String]::IsNullOrEmpty($last_log_file_imported)}

if($current_log_file_status -eq 'Running') {
    logman stop -name �$data_collector_set_name�
    logman start -name �$data_collector_set_name�
}


foreach($perfmonfile in $perfmonfiles)
{
    $sourceBlg = $perfmonfile.FullName;
    $sqlDSNconection = "SQL:$dsn!$sourceBlg"

    $AllArgs = @($sourceBlg, '-f', 'SQL', '-o', $sqlDSNconection)
    $relog_result = relog $AllArgs
}

#Add-OdbcDsn -Name "LocalSqlServer" -DriverName "SQL Server" -DsnType "System" -SetPropertyValue @("Server=MSI", "Trusted_Connection=Yes", "Database=DBA")
