Import-Module dbatools
$src = 'YourDbServer'

$query_dbs = "select name from sys.databases where name <> 'tempdb'";
$query_size = @"
select db_name() as dbName, f.type_desc, sum((f.size*8.0)/1024) as size_MB
from sys.database_files f
group by f.type_desc
"@

$dbs = Invoke-DbaQuery -SqlInstance $src -Query $query_dbs | select -ExpandProperty name;

$DataFileSize_mb_AllDbs = 0.0;
$LogFileSize_mb_AllDbs = 0.0;
foreach($db in $dbs) {
    $size = Invoke-DbaQuery -SqlInstance $src -Query $query_size -Database $db;
    $DataFileSize_mb_AllDbs += ($size | Where-Object {$_.type_desc -eq 'ROWS'}).size_MB
    $LogFileSize_mb_AllDbs += ($size | Where-Object {$_.type_desc -eq 'log'}).size_MB
    #break;
}

Write-Host "`$DataFileSize_mb_AllDbs = $DataFileSize_mb_AllDbs" -ForegroundColor Green;
Write-Host "`$LogFileSize_mb_AllDbs = $LogFileSize_mb_AllDbs" -ForegroundColor Green;
