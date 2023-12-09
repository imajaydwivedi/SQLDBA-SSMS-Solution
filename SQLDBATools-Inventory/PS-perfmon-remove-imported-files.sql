Import-Module dbatools;

$tsql_get_files_imported = "select /* Delete files older than 12 hours */ DisplayString from dbo.DisplayToID where LogStopTime < DATEADD(hour,-4,getdate())";

$files_to_delete = Invoke-DbaQuery -SqlInstance msi -Database DBA -Query $tsql_get_files_imported | Select-Object -ExpandProperty DisplayString;
foreach($file in $files_to_delete)
{   
    if([System.IO.File]::Exists($file)) {
        Write-Output "Deleting file -> $file";
        del $file
    }
}


