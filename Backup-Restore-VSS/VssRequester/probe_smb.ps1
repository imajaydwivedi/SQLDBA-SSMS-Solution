$share = '\\192.168.122.1\vss-transport'
Write-Host "Testing $share ..."
if (Test-Path $share) {
    Write-Host "READ OK"
    $probe = Join-Path $share ("probe_" + $env:COMPUTERNAME + ".txt")
    "hello from $env:COMPUTERNAME at $(Get-Date -Format o)" | Set-Content -Path $probe -Encoding UTF8
    if (Test-Path $probe) {
        Write-Host "WRITE OK - $probe"
        Get-Content $probe
        Remove-Item $probe -Force
        Write-Host "DELETE OK"
    } else {
        Write-Host "WRITE FAILED"
    }
} else {
    Write-Host "READ FAILED - path not reachable"
}
