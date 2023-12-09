cls

$collector_root_directory = 'D:\\MSSQL15.MSSQLSERVER\\SQLWATCH';
$data_collector_set_name = 'DBA';
$data_collector_template_path = �$collector_root_directory\DBA_PerfMon_NonSQL_Collector_Template.xml�;
$log_file_path = "$collector_root_directory\$($env:COMPUTERNAME)__"
$file_rotation_time = '04:00:00'
$sample_interval = '00:00:05'
$version_format = 'yyyyMMdd\-HHmmss'

logman import -name �$data_collector_set_name� -xml �$data_collector_template_path�
logman update -name �$data_collector_set_name� -f bin -cnf "$file_rotation_time" -o "$log_file_path" -si "$sample_interval"
logman start -name �$data_collector_set_name�

<#
logman stop -name �$data_collector_set_name�
logman delete -name �$data_collector_set_name�
#>
