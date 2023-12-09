[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [int]$NoOfIterations = 50,
    [Parameter(Mandatory=$false)]
    [int]$NoOfThreads = 6,
    [Parameter(Mandatory=$false)]
    [string]$SqlInstance = 'localhost',
    [Parameter(Mandatory=$false)]
    [string]$Database = 'StackOverflow',
    [Parameter(Mandatory=$false)]
    [int]$DelayBetweenQueriesMS = 1000,
    [Parameter(Mandatory=$false)]
    [pscredential]$SqlCredential
)

$startTime = Get-Date
#Import-Module dbatools, PoshRSJob;

$ErrorActionPreference = "Stop"

$loops = 1..$($NoOfThreads*$NoOfIterations)
$scriptBlock = {
    Param ($SqlInstance, $Database, $SqlCredential)
    
    #Import-Module dbatools;
    $Id1 = Get-Random -Maximum 10000001
    $id2 = Get-Random -Maximum 10000001
    $id3 = Get-Random -Maximum 10000001

    # Set application/program name
    $appName = switch ($Id1 % 5) {
        0 {"SQLQueryStress"}
        1 {"dbatools"}
        2 {"VS Code"}
        3 {"PowerShell"}
        4 {"Azure Data Studio"}
    }

    # Randonly call b/w 2 logins
    if ( $appName -eq 'SQLQueryStress' ) {
        $con = Connect-DbaInstance -SqlInstance $SqlInstance -Database $Database -SqlCredential $SqlCredential -ClientName $appName
    }
    else {
        $con = Connect-DbaInstance -SqlInstance $SqlInstance -Database $Database -ClientName $appName
    }

    if (($id1 % 8) -eq 0) {
        $r = Invoke-DbaQuery -SqlInstance $con  -Query usp_GetUsersByLocation -SqlParameter @{ Location = "United States" } -CommandType StoredProcedure
    }
    elseif (($id1 % 8) -eq 7) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_GetUsersByLocation -SqlParameter @{ Location = "Germany%" } -CommandType StoredProcedure
    }
    elseif (($id1 % 8) -eq 6) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_GetUsersByLocation -SqlParameter @{ Location = "India%" } -CommandType StoredProcedure
    }
    elseif (($id1 % 8) -eq 5) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_GetUsersByDisplayName -SqlParameter @{ DisplayName = "Brent Ozar" } -CommandType StoredProcedure
    }
    elseif (($id1 % 8) -eq 4) {
        Invoke-DbaQuery -SqlInstance $con -Query usp_GetUsersByDisplayName -SqlParameter @{ DisplayName = "Lady Gaga" } -CommandType StoredProcedure
    }
    elseif (($id1 % 8) -eq 3) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_GetNewPostsForUser 'Jeff Atwood';"
    }
    elseif (($id1 % 8) -eq 2) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_GetNewPostsForUser 'Jon Skeet';"
    }
    else {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_GetNewPostsForUser 'Brent Ozar';"
    }
}
$jobs = $loops | Start-RSJob -Name {"ServerLab2__$_"} -ScriptBlock $scriptBlock -Throttle $NoOfThreads -ModulesToImport dbatools -ArgumentList $SqlInstance, $Database, $SqlCredential

# Get all the jobs
$jobs | Wait-RSJob -ShowProgress

$jobs | Remove-RSJob -Force;

$endTime = Get-Date

$elapsedTime = New-TimeSpan -Start $startTime -End $endTime

"Total time taken = $($elapsedTime.Minutes) minutes $($elapsedTime.Seconds) seconds" | Write-Host -ForegroundColor Yellow


<#
cd $env:USERPROFILE\documents\Lab-Load-Generator\
#$SqlCredential = Get-Credential -UserName 'SQLQueryStress' -Message 'SQLQueryStress'

$params = @{
    SqlInstance = 'SqlPractice'
    Database = 'StackOverflow'
    NoOfIterations = 500
    NoOfThreads = 6
    DelayBetweenQueriesMS = 1000
    SqlCredential = $SqlCredential
}

cls
Import-Module dbatools, PoshRSJob;
.\Invoke-ServerLab2.ps1 @params
#>