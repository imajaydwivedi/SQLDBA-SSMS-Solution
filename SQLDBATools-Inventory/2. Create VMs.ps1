# https://www.oracle.com/technetwork/articles/servers-storage-admin/manage-vbox-cli-2264359.html
    # https://www.virtualbox.org/manual/ch08.html
$machinePath = 'E:\Virtual_Machines\';
#$machines = @('DC','SQL-A','SQL-B','SQL-C','SQL-D','SQL-E','SQL-F','SQL-G');
$machines = @('SQL-A');
$files = @('C_Drive.vhd','D_Drive.vhd','E_Drive.vhd','F_Drive.vhd','G_Drive.vhd','SQL_Data.vhd','SQL_Log.vhd','SQL_TempDb.vhd','SQL_SysDbs.vhd','SQL_Backup.vhd');
$files_20gb = @('SQL_Log.vhd','SQL_TempDb.vhd','SQL_SysDbs.vhd');
$ISOImage_Server = 'E:\Softwares\SW_DVD9_Windows_Svr_Std_and_DataCtr_2012_R2_64Bit_English_-3_MLF_X19-53588.ISO'
$host_Softwares = 'E:\Softwares';
$host_Downloads = 'C:\Users\adwivedi\Downloads'

$vhdStatements = '';

# Set Default Machine Path
vboxmanage setproperty machinefolder $machinePath

# Create VM
foreach($vm in $machines)
{
    # Creating a VM
    VBoxManage createvm --name $vm --ostype Windows2016_64 --register
    #VBoxManage showvminfo $vm

    # Setting Up a VM's Properties
    VBoxManage modifyvm $vm --cpus 2 --memory 2048 --vram 20

    # Set BiDirectional Clipboard
    VBoxManage modifyvm $vm --clipboard bidirectional
    VBoxManage modifyvm $vm -vrde on
    VBoxManage modifyvm $vm --vrde on --vrdemulticon on

    # Configuring a Virtual Network Adapter
        # Host Only
    VBoxManage modifyvm $vm --nic1 hostonly --hostonlyadapter1 vboxnet0
        # Bridged Adapter
    #VBoxManage modifyvm $vm --nic2 bridged
        # NAT
    #VBoxManage modifyvm $vm --nic3 nat
    
    # Register VM
    $vmFilePath = "$($machinePath)$vm\$vm.vbox";
    #VBoxManage registervm $vmFilePath

    # Add Storage controller
    VBoxManage storagectl $vm --name "SATA Controller" --add sata --bootable on

    for($i = 0; $i -lt $files.Length; $i++)
    {
        VBoxManage storageattach $vm --storagectl "SATA Controller" --type hdd --medium $machinePath\VHDs\$vm\$($files[$i]) --port $i --device 0
    }

    # Add CD/DVD 
    VBoxManage storagectl $vm --name "IDE Controller" --add ide;

    # Mount ISO image on CD/DVD
    VBoxManage storageattach $vm --storagectl "IDE Controller" --port 0  --device 0 --type dvddrive --medium $ISOImage_Server

    # Start VM 
    VBoxManage startvm $vm 

    #VirtualBox.exe $vmFilePath
}

<#
vboxmanage unregistervm 'SQL-C' --delete
#>


