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
