$servers = @('MyDbServer01')

$servers_issue = @()
$servers_success = @()

foreach($srv in $servers)
{
    try{
    $svs = Get-Service -ComputerName $srv -ErrorAction Continue | Where-Object {$_.DisplayName -match "SQL Server \(\w+\)"}
    $svs | Stop-Service -Force
    $svs | Set-Service -StartupType Disabled
    $servers_success += $srv
    $svs | ft
    }
    catch {
        $servers_issue += $srv
    }
}

Get-Service -ComputerName $servers_success | Where-Object {$_.DisplayName -match "SQL Server \(\w+\)"} | Select-Object MachineName, Name, DisplayName, Status, StartupType | ogv