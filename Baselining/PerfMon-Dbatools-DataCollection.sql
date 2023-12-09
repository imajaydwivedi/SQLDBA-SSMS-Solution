Template Path
\\dbatestserver\H$\Performance-Issues\DBA_PerfMon_Collector-Template.xml
\GitHub\SQLDBA-SSMS-Solution\Baselining\DBA_PerfMon_Collector-Template.xml
\\Msi\sqlwatch

LogMan.exe => Manage Performance Monitor & performance logs from the command line.
https://docs.microsoft.com/en-us/archive/blogs/jeff_stokes/how-to-sustain-your-data-collector-set-through-a-reboot
http://www.myfaqbase.com/q0001438-Software-OS-Windows-Command-Line-What-is-the-syntax-of-logman-exe-command.html
https://ss64.com/nt/logman.html
https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/logman
https://www.sqlshack.com/sql-server-performance-tuning-using-windows-performance-monitor/
https://www.mssqltips.com/sqlservertip/1722/collecting-performance-counters-and-using-sql-server-to-analyze-the-data/
https://techcommunity.microsoft.com/t5/testingspot-blog/how-to-import-perfmon-logs-into-a-sql-database-to-create-excel/ba-p/367635

cls

$collector_root_directory = 'D:\\MSSQL15.MSSQLSERVER\\SQLWATCH';
$data_collector_template_path = �$collector_root_directory\DBA_PerfMon_Collector-Template.xml�;
$log_file_path = "$collector_root_directory\$($env:COMPUTERNAME)__"
$data_collector_set_name = 'DBA_PerfMon_Collector';
$file_rotation_time = '00:00:05'
$sample_interval = '00:00:05'
$version_format = 'yyyyMMdd\-HHmmss'

logman import -name �$data_collector_set_name� -xml �$data_collector_template_path�
logman update -name �$data_collector_set_name� -f bin -cnf "$file_rotation_time" -o "$log_file_path" -si "$sample_interval"
logman start -name �$data_collector_set_name�

<#
logman stop -name �$data_collector_set_name�
logman delete -name �$data_collector_set_name�
#>


perfmon /sys
