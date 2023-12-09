$server = 'TestVm'

<#
$result_all = Get-DbaDbSpace -SqlInstance $server
# Get Log Shipped Database from Source
$result_rcm = Get-DbaDbSpace -SqlInstance SourceTestVM -Database 'Youtube_20130710_AudioMusic'
#>

# Group result by Database, and Get Drive size required
$result_db_wise = $result_all | Group-Object -Property {$_.Database};
foreach($db in $result_db_wise) {
    $dbName = $db.Name
    $size = ($db.Group.FileSize.Gigabyte | Measure-Object -Sum).Sum;
    Write-Host "[$dbName] => $size gb" -ForegroundColor Green #-BackgroundColor White;
    Get-SpaceToAdd -TotalSpace_GB $size -UsedSpace_GB $size -Percent_Free_Space_Required 35
    Write-Host ''
}

# Get Total Size in GB for Small Dbs
$smallDbs = $result_all | Where-Object {$_.Database -notin @('IDS','tempdb','master','model','msdb') }
$smallDbs_Size_Gb = ($smallDbs.FileSize.Gigabyte | Measure-Object -Sum).Sum;
Get-SpaceToAdd -TotalSpace_GB $smallDbs_Size_Gb -UsedSpace_GB $smallDbs_Size_Gb -Percent_Free_Space_Required 35;

# Get TempDb Size required = 20% of Total All Db size
$allDbs_except_TempDb = $result_all | Where-Object {$_.Database -notin @('tempdb') };
$tempDb_Size_Gb = (($allDbs_except_TempDb.FileSize.Gigabyte | Measure-Object -Sum).Sum) * 0.2;
Get-SpaceToAdd -TotalSpace_GB $tempDb_Size_Gb -UsedSpace_GB $tempDb_Size_Gb -Percent_Free_Space_Required 35;
