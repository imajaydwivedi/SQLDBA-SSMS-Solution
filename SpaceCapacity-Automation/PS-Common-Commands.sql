$server = 'YourDbServerName'
#Get-VolumeInfo $server | ogv
Get-OrphanDatabaseFiles -SqlInstance $server -Directory 'F:\'
#Get-SpaceToAdd -TotalSpace_GB 1560 -UsedSpace_GB 1297 -Percent_Free_Space_Required 35
$files = Get-DbaDbFile -SqlInstance $server;
$files | where {$_.PhysicalName -like 'F:\*' -and $_.Size.Gigabyte -ge 5} | `
    select SqlInstance, Database, TypeDescription, LogicalName, PhysicalName, Size | ogv



$ScriptBlock = {
    Import-Module SQLDBATools,dbatools;
    $query = @"
    USE [StackOverflow]
    DBCC SHRINKFILE (N'StackOverflow' , 45000)
    GO
"@;

    Invoke-DbaQuery -SqlInstance $server -Query $query
}

Start-Job -ScriptBlock $ScriptBlock -Name server_Shrink_StackOverflow