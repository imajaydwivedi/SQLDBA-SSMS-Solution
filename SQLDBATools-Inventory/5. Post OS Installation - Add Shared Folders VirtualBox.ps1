$machines = @('DC','SQL-A','SQL-B','SQL-C','SQL-D','SQL-E','SQL-F','SQL-G');
$host_Softwares = 'E:\Softwares';
$host_Downloads = 'C:\Users\adwivedi\Downloads'

foreach($vm in $machines)
{
    # Add shared folders
    VBoxManage sharedfolder add $vm --name Host_Softwares --hostpath $host_Softwares --automount;
    VBoxManage sharedfolder add $vm --name Host_Downloads --hostpath $host_Downloads --automount;

    # Configuring a Virtual Network Adapter
        # Bridged Adapter
    VBoxManage modifyvm $vm --nic2 bridged
        # NAT
    VBoxManage modifyvm $vm --nic3 nat
}
