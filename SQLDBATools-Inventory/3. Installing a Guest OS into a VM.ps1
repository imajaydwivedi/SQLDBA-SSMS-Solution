# Set TimeZone to IST
Set-TimeZone -Id 'India Standard Time'

# Enable .net framework 3.5
DISM /Online /Enable-Feature /FeatureName:NetFx3 /All
    # Or
Install-WindowsFeature Net-Framework-Core -source D:\sources\sxs

# Change IP of machine for Host-Only Adapter
Netsh interface ipv4 set address "Ethernet" static 10.10.10.10
Netsh interface ipv4 set dnsservers "Ethernet" static 10.10.10.10 primary


# Rename Computer
Netdom renamecomputer %computername% /newname:DC
    # Or
Rename-computer –computername “$($env:COMPUTERNAME)” –newname “DC” -Restart;

# Join to Domain
add-computer –domainname Contoso.com -Credential Contso\Ajay -restart –force


# Install Active Directory Domain Services on Domain Controller
Add-WindowsFeature -Name 'AD-Domain-Services'
# Install Powershell Module
Add-WindowsFeature -Name 'RSAT-AD-Powershell'
# Active Directory LDAP
Add-WindowsFeature -Name 'ADLDS'
# Telnet client
Add-WindowsFeature -Name 'Telnet-Client'
# AD Management Tools
Add-WindowsFeature -Name 'RSAT-AD-Tools'

# Enable remote desktop (RDP) connections
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
                -Name "fDenyTSConnections" `
                –Value 0;
# Configure Firewall ports
Enable-NetFirewallRule -DisplayGroup "Remote Desktop";

# Network Discovery
netsh advfirewall firewall set rule group=”network discovery” new enable=yes



#
# Windows PowerShell script for AD DS Deployment
#
Import-Module ADDSDeployment
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "Win2012R2" `
-DomainName "Contso.com" `
-DomainNetbiosName "CONTSO" `
-ForestMode "Win2012R2" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\Windows\SYSVOL" `
-Force:$true



VBoxManage startvm "DC" --type headless
#VBoxManage controlvm "DC" poweroff
VBoxManage controlvm "DC" savestate