#$server = @('PrimaryReplica','SecondaryReplica')
$database = 'facebook'

$db_files = Get-DbaDbFile -SqlInstance $server[0] -Database $database



$disk_space = Get-DbaDiskSpace $server
$Computers = $disk_space | Select-Object -ExpandProperty ComputerName -Unique
$db_mps = @()
foreach($file in $db_files)
{
    $file_path = $file.PhysicalName;
    foreach($machine in $Computers)
    {
        $matched_mps = @();
        $max_mp_length = 0
        foreach($mp in $($disk_space | ? {$_.ComputerName -eq $machine})) 
        {
            $mp_name = $mp.Name
            if($file_path -like "$mp_name*") {
                if($mp_name.Length -gt $max_mp_length) {
                    $max_mp_length = $mp_name.Length
                }
                $matched_mps += $mp
            }
        }
        $db_mps += ($matched_mps | ? {$_.Name.Length -eq $max_mp_length});
    }
}
#$db_mps | ogv -Title "Db Specific Mount Points"
cls
$db_mps | ft -AutoSize

$Threshold = 75
$db_files_filtered = $db_files | where-object {$_.TypeDescription -eq 'ROWS'}
foreach($file in $db_files_filtered) {
    $Database = $file.Database
    $LogicalName = $file.LogicalName
    $PhysicalName = $file.PhysicalName
    $Size = $file.Size.Megabyte
    $UsedSpace = $file.UsedSpace.Megabyte
    $AvailableSpace = $file.AvailableSpace.Megabyte

    $NewSize = [Math]::Ceiling(($UsedSpace*100.0)/$Threshold)
    $SpaceToAdd = $NewSize-$Size

    $tsql_modifyFile = @"

USE [master]
GO
-- Total = $([Math]::Ceiling($file.Size.Gigabyte)) GB, %Used = $($UsedSpace*100/$Size)
    -- Add $SpaceToAdd MB space in file to increase size from $Size MB to $NewSize MB with threshold of $Threshold%
    -- PhysicalName -> $PhysicalName
ALTER DATABASE [$database] MODIFY FILE ( NAME = N'$LogicalName', SIZE = $($NewSize)MB )
GO
"@

    $tsql_modifyFile
}
