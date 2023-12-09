cls
$server = 'MSI'
$path = 'K:\'
$auto_delete = $true
$threshold_days_delete = 60

$disk_files = Get-ChildItem $path* -Recurse -ErrorAction Ignore -Include *.mdf, *.ndf, *.ldf;
$tsql_files = 'select physical_name from sys.master_files';
$db_files = (Invoke-DbaQuery -SqlInstance $server -Query $tsql_files).physical_name
$date_threshold = (Get-Date).AddDays(-$threshold_days_delete)
foreach($file in $disk_files)
{
    $FullName = $file.FullName;
    $LastWriteTime = $file.LastWriteTime;
    if($FullName -notin $db_files) {
        if($LastWriteTime -le $date_threshold) {
            Write-Host "LastWriteTime | $LastWriteTime | '$FullName'" -ForegroundColor Red;
            if($auto_delete){Remove-Item $FullName;}
        }
        else {
            Write-Host "LastWriteTime | $($file.LastWriteTime) | '$FullName'" -ForegroundColor Green;
        }
    }
}
