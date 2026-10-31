<#
When multiple network adaptors are present, the one with the lowest metric is used for outbound traffic. 

This script sets the metric for the local network adaptor to a lower value to ensure it is prioritized over other adaptors.

This is especially useful in lab environments where multiple network adaptors may be present, such as virtual machines with both NAT and bridged adapters.

Objective: Set the network priority on SQLMonitor which is having multiple network adaptors
#>

# Ensure IST timezone for all machines
Set-TimeZone -Id 'India Standard Time'

# List network adaptors
Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed

# Check current interface metrics
Get-NetIPInterface | Select-Object InterfaceAlias, InterfaceMetric, AddressFamily

# if required, disable IPv6

# Set a lower metric for the local network adapter (higher priority)
Set-NetIPInterface -InterfaceAlias "Inet1" -InterfaceMetric 10

# Verify
Get-NetIPInterface | Select-Object InterfaceAlias, InterfaceMetric, AddressFamily

# Restart networking services
Get-NetAdapter | Restart-NetAdapter
