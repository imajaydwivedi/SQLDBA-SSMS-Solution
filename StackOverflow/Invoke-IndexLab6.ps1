[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [int]$NoOfIterations = 100,
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
Import-Module dbatools, PoshRSJob;

$ErrorActionPreference = "Stop"
"`n`n`n`n`n`nStart Time => $($startTime.ToString('yyyy-MM-dd hh:mm.ss'))"

if ([String]::IsNullOrEmpty($SqlCredential)) {
    "Kindly provide `$SqlCredential " | Write-Error
}

$loops = 1..$($NoOfThreads*$NoOfIterations)
$scriptBlock = {
    Param ($SqlInstance, $Database, $SqlCredential, $DelayBetweenQueriesMS)

    # Import-Module dbatools
    $id1 = Get-Random -Maximum 10000001
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

    if (($id1 % 30) -eq 24) {
        $sql = "EXEC dbo.usp_Q1718 @UserId = $id1;"
    }
    elseif (($id1 % 30) -eq 23) {
        $sql = "EXEC dbo.usp_Q2777;"
    }
    elseif (($id1 % 30) -eq 22) {
        $sql = "EXEC dbo.usp_Q181756 @Score = $id1, @Gold = $id2, @Silver = $id3;"
    }
    elseif (($id1 % 30) -eq 21) {
        $sql = "EXEC usp_Q69607 @UserId = $id1;"
    }
    elseif (($id1 % 30) -eq 20) {
        $sql = "EXEC usp_Q8553 @UserId = $id1;"
    }
    elseif (($id1 % 30) -eq 19) {
        $sql = "EXEC usp_Q10098 @UserId = $id1;"
    }
    elseif (($id1 % 30) -eq 18) {
        $sql = "EXEC usp_Q17321 @UserId = $id1;"
    }
    elseif (($id1 % 30) -eq 17) {
        $sql = "EXEC usp_Q25355 @MyId = $id1, TheirId = $id2;"
    }
    elseif (($id1 % 30) -eq 16) {
        $sql = "EXEC usp_Q74873 @UserId = $id1;"
    }
    elseif (($id1 % 30) -eq 15) {
        $sql = "EXEC dbo.usp_Q9900 @UserId = $id1;"
    }
    elseif (($id1 % 30) -eq 14) {
        $sql = "EXEC usp_Q49864 @UserId = $id1;"
    }
    elseif (($id1 % 30) -eq 13) {
        $sql = "EXEC usp_Q283566;"
    }
    elseif (($id1 % 30) -eq 12) {
        $sql = "EXEC usp_Q66093 @UserId = $id1;"
    }
    elseif (($id1 % 30) -eq 10) {
        $sql = "EXEC dbo.usp_SearchUsers @DisplayNameLike = 'Brent', @LocationLike = NULL, @WebsiteUrlLike = 'Google', @SortOrder = 'Age';"
    }
    elseif (($id1 % 30) -eq 9) {
        $sql = "EXEC dbo.usp_SearchUsers @DisplayNameLike = NULL, @LocationLike = 'Chicago', @WebsiteUrlLike = NULL, @SortOrder = 'Location';"
    }
    elseif (($id1 % 30) -eq 8) {
        $sql = "EXEC dbo.usp_SearchUsers @DisplayNameLike = NULL, @LocationLike = NULL, @WebsiteUrlLike = 'BrentOzar.com', @SortOrder = 'Reputation';"
    }
    elseif (($id1 % 30) -eq 7) {
        $sql = "EXEC usp_SearchUsers @DisplayNameLike = 'Brent', LocationLike = 'Chicago', WebsiteUrlLike = 'BrentOzar.com', SortOrder = 'DownVotes';"
    }
    elseif (($id1 % 30) -eq 6) {
        $sql = "EXEC usp_FindInterestingPostsForUser @UserId = $id1, SinceDate = '2017/06/10';"
    }
    elseif (($id1 % 30) -eq 5) {
        $sql = "EXEC usp_CheckForVoterFraud @UserId = $id1;"
    }
    elseif (($id1 % 30) -eq 4) {
        $sql = "EXEC usp_AcceptedAnswersByUser @UserId = $id1;"
    }
    elseif (($id1 % 30) -eq 3) {
        $sql = "EXEC usp_AcceptedAnswersByUser @UserId = $id3;"
    }
    elseif (($id1 % 30) -eq 2) {
        $sql = "EXEC usp_BadgeAward @Name = 'Loud Talker', UserId = 26837;"
    }
    elseif (($id1 % 30) -eq 1) {
        $sql = "EXEC usp_Q43336;"
    }
    else {
        $sql = "EXEC usp_Q40304;"
    }

    $sql = $sql + @"

WHILE @@TRANCOUNT > 0
	BEGIN
	COMMIT
    END
"@
    $r = Invoke-DbaQuery -SqlInstance $con -Query $sql -ErrorAction Stop
    Start-Sleep -Milliseconds $DelayBetweenQueriesMS
}
$jobs = $loops | Start-RSJob -Name {"IndexLab6__$_"} -ScriptBlock $scriptBlock -Throttle $NoOfThreads -ModulesToImport dbatools `
            -ArgumentList $SqlInstance, $Database, $SqlCredential, $DelayBetweenQueriesMS

# Get all the jobs
$jobs | Wait-RSJob -ShowProgress

$jobs | Remove-RSJob -Force;

$endTime = Get-Date
"End Time => $($endTime.ToString('yyyy-MM-dd hh:mm.ss'))"
$elapsedTime = New-TimeSpan -Start $startTime -End $endTime

"Total Time Taken => `n`n$elapsedTime" | Write-Host -ForegroundColor Yellow


<#
cd $env:USERPROFILE\documents\Lab-Load-Generator\
#$SqlCredential = Get-Credential -UserName 'SQLQueryStress' -Message 'SQLQueryStress'

# Restart Computer to reset IO Stats
Restart-Computer -ComputerName SqlPractice -Force -Wait -Verbose

$params = @{
    SqlInstance = 'SqlPractice'
    Database = 'StackOverflow'
    NoOfIterations = 500
    NoOfThreads = 6
    DelayBetweenQueriesMS = 100
    SqlCredential = $SqlCredential
}

cls
Import-Module dbatools, PoshRSJob;
$counter = 1
while ($counter -lt 24) {
.\Invoke-IndexLab6.ps1 @params
Start-Sleep -Seconds 600
$counter = $counter + 1
}
#>