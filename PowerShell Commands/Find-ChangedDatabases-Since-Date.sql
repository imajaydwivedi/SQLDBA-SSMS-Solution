$Server = 'SomeServerName'
$query = "select db_name(mf.database_id) as dbName, mf.physical_name from sys.master_files mf"

$result = Invoke-DbaQuery -SqlInstance $Server -Query $query;
$thresholdDateString = '05-Dec-19'
$thresholdDate = [datetime]::parseexact($thresholdDateString, 'dd-MMM-yy', $null)

$changedFileList = @();
foreach($i in $result) {
    $dbName = $i.dbName;
    $filePath = $i.physical_name;
    $fileName = "\\$Server\" + $filePath.Replace(':','$');
    
    #Write-Host $fileName
    $file = Get-Item $fileName
    #$file.LastWriteTime
    $hasChanged = $false
    if($file.LastWriteTime -gt $thresholdDate) {
        $hasChanged = $true
    } 

    $props = [ordered]@{
                DbName = $dbName;
                PhysicalName = $filePath;
                HasChangedSinceLastRestore = $hasChanged;
            }

    $obj = New-Object -TypeName psobject -Property $props
    $changedFileList += $obj
}

$changedFileList `
    | Where-Object {$_.HasChangedSinceLastRestore} `
    | Select-Object DbName, HasChangedSinceLastRestore -Unique `
    | Sort-Object -Property DbName | ogv;

