# Parameters
$InstanceBaseName = 'SQLEXPRESS' # Like 'PR1'
$SetupFolder = 'C:\SQLSvr2019Ent-ServerCAL'

# Stop if any failure occurrs
$ErrorActionPreference = "Stop"

# Validate setup folder path to be C:\
Set-location $SetupFolder;
if ( (-not [string]::IsNullOrEmpty($PSScriptRoot)) -and ($PSScriptRoot -ne $SetupFolder) ) {
    "This script should be present inside SetupFolder, and `t setup folder should be present on C:\ drive" | Write-Error -ErrorAction Stop
}

try { 
    $startTime = Get-Date
    "($($startTime.ToString('yyyy-MM-dd HH:mm:ss'))) (START) Launch setup.exe to upgrade [$($env:COMPUTERNAME)\$InstanceBaseName] SqlInstance.." | Write-Host -ForegroundColor Yellow
    
    ./setup.exe /q /ACTION=UPGRADE /INSTANCENAME=$InstanceBaseName /IACKNOWLEDGEENTCALLIMITS=True `
        /UpdateEnabled=True /UpdateSource="$(Join-Path $SetupFolder 'Updates')" `
        /IAcceptSQLServerLicenseTerms | % { if (-not [String]::IsNullOrEmpty($_)) { "($($startTime.ToString('yyyy-MM-dd HH:mm:ss'))) (SETUP) $_" } } | Write-Host -ForegroundColor Cyan
    #/SkipRules=Cluster_IsWMIServiceOperational
    
    #Start-Sleep -s 30 # Wait

    $summaryFile = "C:\Program Files\Microsoft SQL Server\150\Setup Bootstrap\Log\Summary.txt"
    $summary = Get-Content $summaryFile
    "($($startTime.ToString('yyyy-MM-dd HH:mm:ss'))) (INFO) Opening '$summaryFile'.." | Write-Host -ForegroundColor Cyan
    if ($Host.Name -ne 'ServerRemoteHost') {
        $summary | ogv -Title 'Summary.txt'
    }
    else {
        $summary | Write-Output
    }

    $endTime = Get-Date
    "`n($($endTime.ToString('yyyy-MM-dd HH:mm:ss'))) (INFO) Upgrade of [$($env:COMPUTERNAME)\$InstanceBaseName] SqlInstance completed" | Write-Host -ForegroundColor Green

    $duration = New-TimeSpan -Start $startTime -End $endTime
    "($($endTime.ToString('yyyy-MM-dd HH:mm:ss'))) (INFO) Upgrade took $([Math]::Round($duration.TotalMinutes,2)) minutes to complete." | Write-Host -ForegroundColor Green -BackgroundColor DarkYellow
}
Catch {      
    $errMessage = $_
    "`nSQL Server Upgrade for [$($env:COMPUTERNAME)\$InstanceBaseName] failed, Go to summary.txt in setupbootstrap folder" | Write-Host -Foregroundcolor Red;
    "****" * 20
    "****" * 20
    Invoke-Item 'C:\Program Files\Microsoft SQL Server\150\Setup Bootstrap\Log'
    throw $_
}
