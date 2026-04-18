Write-Host "Domain: $((Get-WmiObject Win32_ComputerSystem).Domain)"
Write-Host "PartOfDomain: $((Get-WmiObject Win32_ComputerSystem).PartOfDomain)"
Write-Host "--- VSS Writers (SqlServerWriter) ---"
(vssadmin list writers 2>&1 | Out-String) -split "`r`n`r`n" | Where-Object { $_ -match 'SqlServerWriter' }
Write-Host "--- dotnet ---"
$dn = Get-Command dotnet -ErrorAction SilentlyContinue
if ($dn) { dotnet --list-runtimes | Out-String } else { Write-Host 'no dotnet' }
Write-Host "--- PS version ---"
$PSVersionTable.PSVersion.ToString()
Write-Host "--- ComputerName + OS ---"
"$env:COMPUTERNAME  $((Get-WmiObject Win32_OperatingSystem).Caption)"
