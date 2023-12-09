$dbServer = 'someservername'
$drive = 'G:\'

$tsqlQuery = @"
select db_name(mf.database_id) as dbName, mf.name, mf.type_desc, mf.physical_name 
from sys.master_files mf where mf.physical_name like '$drive%';
"@;

$rs = Invoke-DbaQuery -SqlInstance $dbServer -Query $tsqlQuery;

#$files = Invoke-Command -ComputerName $dbServer -ScriptBlock {Get-ChildItem -Path 'H:\MSSQL15.MSSQLSERVER\Data' -Recurse}
$scriptBlock = {
    Get-ChildItem -Path $Using:drive -Recurse | Where-Object {-not $_.PSIsContainer} | Where-Object {$_.Extension -eq '.mdf' -or $_.Extension -eq '.ndf' -or $_.Extension -eq '.ldf'}
}
$files = Invoke-Command -ComputerName $dbServer -ScriptBlock $scriptBlock;


$dbFiles = $rs | Select-Object -ExpandProperty physical_name;
$diskFiles = $files;

foreach($fl in $diskFiles)
{
    $diskFile = $fl.FullName;
    if($diskFile -in $dbFiles) {
        Write-Host "$diskFile is ACTIVE file" -ForegroundColor Green;
    }
    else {
        Write-Host "$diskFile is NOT active db file" -ForegroundColor Red;
    }
}


