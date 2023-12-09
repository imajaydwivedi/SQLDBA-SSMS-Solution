$dbatools_latestversion = ((Get-Module dbatools -ListAvailable | Sort-Object Version -Descending | select -First 1).Version);
Import-Module dbatools -RequiredVersion $dbatools_latestversion;
Import-Module ImportExcel, PoshRSJob -DisableNameChecking;

$InventoryDBA = 'InventoryServer';

# Get list of Server & MountPoint
$tsql_MountPoints = @"
select ServerInstance, MountPoint
from DBA..Disk_Consolidation_Mapping as m
where IsMoveCompleted = 1
--
union
--
select d.FriendlyName as ServerInstance, m.MountPoint
from DBA..Disk_Consolidation_Mapping as m
join [SomeOtherServer].dbainfra.dbo.database_server_inventory as i
	on i.FriendlyName = m.ServerInstance
join [SomeOtherServer].dbainfra.dbo.database_server_inventory as d
	on d.Dataserver = i.DRDataserver
where IsMoveCompleted = 1
"@
$result_MountPoints = Invoke-DbaQuery -SqlInstance $InventoryDBA -Query $tsql_MountPoints;

# Loop through list of Prod/Dr + MountPoint combination, and start Concurrent Job to get Db File Details
$result_MountPoints | 
Start-RSJob -Name {"Orphan_$($_.ServerInstance)_$($_.MountPoint)"} -Throttle 8 -ScriptBlock {
    $server = $_.ServerInstance
    $path = $_.MountPoint
    $auto_delete = $false;
    $threshold_days_delete = 60;

    $ScriptBlock = {
        Param($server,$path)
        
        $disk_files = Get-ChildItem $path -Recurse -ErrorAction Ignore -Include *.mdf, *.ndf, *.ldf; 
        $tsql_files = "select physical_name from sys.master_files with (nolock) where physical_name like ('$path'+'\%')";
        $db_files = (Invoke-DbaQuery -SqlInstance $server -Query $tsql_files).physical_name;

        [System.Collections.ArrayList]$MoutPointFiles = @()
        foreach($file in $disk_files)
        {
            $FullName = $file.FullName;
            $LastWriteTime = $file.LastWriteTime;
            $IsOrphan = $false;
            $Days = (New-TimeSpan -Start $LastWriteTime -End (Get-Date)).Days;
            $Size_mb = $file.length/1MB;

            if($FullName -notin $db_files) {
                $IsOrphan = $true;
            }

            $obj = [PSCustomObject]@{
                        ServerInstance = $server;
                        MountPoint = $path;
                        PhysicalName = $FullName;
                        Size_Mb = $Size_mb;
                        LastWriteTime = $LastWriteTime;
                        LastWrite_days = $Days
                        IsOrphan = $IsOrphan;
                   }
            $MoutPointFiles.Add($obj)|Out-Null
        } # Foeach $disk_files

        $MoutPointFiles | Write-Output;        
    } # $ScriptBlock

    Invoke-Command -ComputerName ([System.Net.Dns]::GetHostByName($server)).Hostname -ScriptBlock $ScriptBlock -ArgumentList $server, $path;
} # Start-RSJob

# Get all the running jobs
$jobs = Get-RSJob | ? { $_.Name -like 'Orphan_*' }
$runningjobs = ($jobs | ? {$_.State -ne 'Completed'}).Count
$total = $jobs.count

# Loop while there are running jobs, and display progress
while($runningjobs -gt 0) {
    # Update progress based on how many jobs are done yet.
    write-progress -activity "Getting Db files on Mount Points.." -status "$($total-$runningjobs)/$total jobs completed" -percentcomplete (($total-$runningjobs)/$total*100)

    # After updating the progress bar, get current job count
    $runningjobs = ($jobs | ? {$_.State -ne 'Completed'}).Count
}

$Result_ServerDiskFiles = $jobs | Receive-RSJob;
$jobs | Remove-RSJob

$OrphanDbFiles = $Result_ServerDiskFiles | ? {$_.IsOrphan} | Sort-Object LastWriteTime -Descending;
$OrphanDbFiles | ogv -Title 'Orphan Db files'
# Save data of only Orphan Files into Excel
$OrphanDbFiles | Export-Excel \\SomeOtherServer\d$\Ajay\Disk-Consolidation-Mapping\OrphanFiles_$(Get-Date -Format yyyyMMdd_HHmm).xlsx -WorksheetName 'Orphan Files'
# Push data of all db files on disk into Infra table DBA..OrphanFiles
$Result_ServerDiskFiles | Write-DbaDataTable -SqlInstance $InventoryDBA -Database 'DBA' -Table 'OrphanFiles' -AutoCreateTable -Truncate;

# Calculate Space being Freed
$tsql_MountPoints_FreedSpace = @"
select ServerInstance, MountPoint, 
		[Freed-Space-GB] = (SUM(Size_Mb)*1.0)/1024
from DBA.dbo.OrphanFiles
where IsOrphan = 1
group by ServerInstance, MountPoint
order by ServerInstance, [Freed-Space-GB] desc
"@
$Result_MountPoints_FreedSpace = Invoke-DbaQuery -SqlInstance $InventoryDBA -Query $tsql_MountPoints_FreedSpace;
$Result_MountPoints_FreedSpace | ogv -Title 'Free Space after Removal of Orphan Files'

# Group Orphan Files by Server+MountPoint pairs
$OrphanDbFiles_Groups = $OrphanDbFiles | Group-Object -Property ServerInstance, MountPoint | 
    Select-Object @{n='ServerInstance'; e={$_.Values[0]}},
                    @{n='MountPoint'; e={$_.Values[1]}},
                    @{n='Files'; e={$_.Group}};
$OrphanDbFiles_Groups | ogv -Title 'Orphan Db Files Grouping'

# Start concurrent connect for each pair of (Server,MountPoint), and rename OrphanFiles files
$OrphanDbFiles_Groups | 
Start-RSJob -Name {"Rename_$($_.ServerInstance)_$($_.MountPoint)"} -Throttle 8 -ScriptBlock {
    $server = $_.ServerInstance
    $PSComputerName = ([System.Net.Dns]::GetHostByName($server)).Hostname;
    $path = $_.MountPoint
    $filesPath = $_.Files.PhysicalName;
    
    $ScriptBlock = {
        Param($server,$path,$filesPath)
        
        [System.Collections.ArrayList]$Files = @()
        foreach($filepath in $filesPath)
        {
            $fileBaseName = Split-Path $filepath -Leaf;
            $fileNewName = "DELETE__$fileBaseName";
            $fileDir = Split-Path $filepath -Parent;
            $fileNewPath = Join-Path -Path $fileDir -ChildPath $fileNewName;

            Rename-Item -Path $filepath -NewName $fileNewName;
            $IsRenameSuccessFull = $true;
            if([System.IO.File]::Exists($filepath)) {
                $IsRenameSuccessFull = $false;
            }
            
            $obj = [PSCustomObject]@{
                        ServerInstance = $server;
                        MountPoint = $path;
                        PhysicalName = $filepath;
                        PhysicalName_New = $fileNewPath;
                        IsRenameSuccessFull = $IsRenameSuccessFull;
                   }
            $Files.Add($obj)|Out-Null
        } # Foreach $filesPath

        $Files | Write-Output;

    } # $ScriptBlock

    Invoke-Command -ComputerName $PSComputerName -ScriptBlock $ScriptBlock -ArgumentList $server, $path, $filesPath;
} # Start-RSJob

# Get all the running jobs
$jobs = Get-RSJob | ? { $_.Name -like 'Rename_*' }
$runningjobs = ($jobs | ? {$_.State -ne 'Completed'}).Count
$total = $jobs.count

# Loop while there are running jobs, and display progress
while($runningjobs -gt 0) {
    # Update progress based on how many jobs are done yet.
    write-progress -activity "Getting Db files on Mount Points.." -status "$($total-$runningjobs)/$total jobs completed" -percentcomplete (($total-$runningjobs)/$total*100)

    # After updating the progress bar, get current job count
    $runningjobs = ($jobs | ? {$_.State -ne 'Completed'}).Count
}

$Result_RenameDbFiles = $jobs | Receive-RSJob;
$Result_RenameDbFiles | ogv -Title "Orphan Db Files Rename Status"
$jobs | Remove-RSJob

# Save data of Renamed Orphan Files into Excel
$Result_RenameDbFiles | Export-Excel \\SomeOtherServer\d$\Ajay\Disk-Consolidation-Mapping\Renamed_OrphanFiles_$(Get-Date -Format yyyyMMdd_HHmm).xlsx -WorksheetName 'Rename_Stats'
# Push data of all db files on disk into Infra table DBA..OrphanFiles_Renamed
$Result_RenameDbFiles | Write-DbaDataTable -SqlInstance $InventoryDBA -Database 'DBA' -Table 'OrphanFiles_Renamed' -AutoCreateTable -Truncate;

#Remove-Variable -Name Result_