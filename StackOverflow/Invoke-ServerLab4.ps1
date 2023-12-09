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
#Import-Module dbatools, PoshRSJob;

$ErrorActionPreference = "Stop"

if ([String]::IsNullOrEmpty($SqlCredential)) {
    "Kindly provide `$SqlCredential " | Write-Error
}

$loops = 1..$($NoOfThreads*$NoOfIterations)
$scriptBlock = {
    Param ($SqlInstance, $Database, $SqlCredential)
    
    #Import-Module dbatools;
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

    if (($id1 % 20) -eq 0) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC dbo.usp_Q36660;"
    }
    elseif (($id1 % 20) -eq 19) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Q975 -CommandType StoredProcedure
    }
    elseif (($id1 % 20) -eq 18) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Report1 -SqlParameter @{ DisplayName = "Brent Ozar" } -CommandType StoredProcedure
    }
    elseif (($id1 % 20) -eq 17) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Report1 -SqlParameter @{ DisplayName = 'Jon Skeet' } -CommandType StoredProcedure
    }
    elseif (($id1 % 20) -eq 16) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Report2 -SqlParameter @{ LastActivityDate = '2016/01/01'; Tags = '%<indexing>%' } -CommandType StoredProcedure
    }
    elseif (($id1 % 20) -eq 15) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_Report2 -SqlParameter @{ LastActivityDate = '2017-07-17 23:16:39.037'; Tags = '%<indexing>%' } -CommandType StoredProcedure
    }
    elseif (($id1 % 20) -eq 14) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_CommentsByUserDisplayName -SqlParameter @{ DisplayName = 'ZXR' } -CommandType StoredProcedure
    }
    elseif (($id1 % 20) -eq 13) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_CommentsByUserDisplayName -SqlParameter @{ DisplayName = 'GmA' } -CommandType StoredProcedure
    }
    elseif (($id1 % 20) -eq 12) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_CommentsByUserDisplayName -SqlParameter @{ DisplayName = 'Fred -ii-' } -CommandType StoredProcedure
    }
    elseif (($id1 % 20) -eq 11) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_CommentsByUserDisplayName -SqlParameter @{ DisplayName = 'Lightness Races in Orbit' } -CommandType StoredProcedure
    }
    elseif (($id1 % 20) -eq 10) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_CommentInsert -SqlParameter @{ PostId = $id1; UserId = $id2; Text = 'Nice post!' } -CommandType StoredProcedure
    }
    elseif (($id1 % 20) -eq 9) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_PostViewed -SqlParameter @{ PostId = $id1; UserId = $id2 } -CommandType StoredProcedure
    }
    elseif (($id1 % 20) -eq 8) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_VoteInsert -SqlParameter @{ PostId = $id1; UserId = $id2; BountyAmount = $id3; VoteTypeId = 3 } -CommandType StoredProcedure
    }
    elseif (($id1 % 20) -eq 7) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC dbo.usp_CommentInsert @PostId = @Id1, @UserId = @Id2, @Text = 'Nice post!';"
    }
    elseif (($id1 % 20) -eq 6) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_VoteInsert -SqlParameter @{ PostId = $id1; UserId = $id2; BountyAmount = $id3; VoteTypeId = 6 } -CommandType StoredProcedure
    }
    elseif (($id1 % 20) -eq 5) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_VoteInsert -SqlParameter @{ PostId = $id1; UserId = $id2; BountyAmount = $id3; VoteTypeId = 7 } -CommandType StoredProcedure
    }
    elseif (($id1 % 20) -eq 4) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_VoteInsert -SqlParameter @{ PostId = $id1; UserId = $id2; BountyAmount = $id3; VoteTypeId = 2 } -CommandType StoredProcedure
    }
    else {
        $r = Invoke-DbaQuery -SqlInstance $con -Query usp_VoteInsert -SqlParameter @{ PostId = $id1; UserId = $id2; BountyAmount = $id3; VoteTypeId = 5 } -CommandType StoredProcedure
    }
}
$jobs = $loops | Start-RSJob -Name {"ServerLab4__$_"} -ScriptBlock $scriptBlock -Throttle $NoOfThreads -ModulesToImport dbatools -ArgumentList $SqlInstance, $Database, $SqlCredential

# Get all the jobs
$jobs | Wait-RSJob -ShowProgress

$jobs | Remove-RSJob -Force;

$endTime = Get-Date

$elapsedTime = New-TimeSpan -Start $startTime -End $endTime

"Total time taken = $("{0:N0}" -f $elapsedTime.TotalHours) hours $($elapsedTime.Minutes) minutes $($elapsedTime.Seconds) seconds" | Write-Host -ForegroundColor Yellow


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
.\Invoke-ServerLab4.ps1 @params
#>