$machines = @($env:COMPUTERNAME);
$Volumes = @('C:','D:','E:','F:','E:\Data','E:\Log','E:\TempDb','E:\SysDbs','E:\Backup');

foreach($vm in $machines)
{
    #$disks = Get-Disk | Select-Object Number, OperationalStatus, NumberOfPartitions, @{l='Size_GB';e={$_.Size/1gb}} | Sort-Object Number;
    $disks = Get-Disk | Sort-Object Number;
    <#
        Assumptions:-
            1) Disk 0 is already mounted as C:\ drive
            2) Drive D:\ is taken by CD/DVD Drive
    #>

    # Change Drive Letter to O:\ for Optical Drive
    Get-WmiObject -Class Win32_volume -Filter "DriveType = 5" | Set-WmiInstance -Arguments @{DriveLetter='O:'} | Out-Null;

    #foreach($disk in $disks) 
    for($i = 1;$i -lt $disks.Count; $i++)
    {
        
        # Initialize the Offline Disk
        if($disks[$i].PartitionStyle -eq 'Raw') {
            Initialize-Disk -Number $disks[$i].Number -PartitionStyle MBR;
        }
        
        # Setup a Partition
        if($disks[$i].NumberOfPartitions -eq 0) 
        {
            $disks[$i] | New-Partition -UseMaximumSize;
            $Partition = Get-Partition -DiskNumber $disks[$i].Number;   
            $Partition | Format-Volume -FileSystem NTFS -Confirm:$false;

            # If Path does not exists
            if(![System.IO.Directory]::Exists($Volumes[$i]))
            {
                if($Volumes[$i].IndexOf('\') -ne -1) 
                { 
                    New-Item -ItemType Directory -Path $Volumes[$i];
                }
            }

            $Partition | Add-PartitionAccessPath -AccessPath $Volumes[$i];
        }
    }
}

<# ## Clear-Disk ##

$machines = @($env:COMPUTERNAME
$Volumes = @('C:','D:','E:','F:','E:\Data','E:\Log','E:\TempDb','E:\SysDbs','E:\Backup');

foreach($vm in $machines)
{
    $confirmpreference = 'none'
    $disks = Get-Disk | Sort-Object Number;

    for($i = 1;$i -lt $disks.Count; $i++)
    {
        
        $disks[$i] | Clear-Disk -RemoveData;
    }
}
#>