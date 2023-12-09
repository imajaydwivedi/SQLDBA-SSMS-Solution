[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [int]$NoOfIterations = 10000,
    [Parameter(Mandatory=$false)]
    [int]$NoOfThreads = 100,
    [Parameter(Mandatory=$false)]
    [string]$SqlInstance = 'localhost',
    [Parameter(Mandatory=$false)]
    [string]$Database = 'StackOverflow',
    [Parameter(Mandatory=$false)]
    [int]$DelayBetweenQueriesMS = 100,
    [Parameter(Mandatory=$false)]
    [pscredential]$SqlCredential
)

$startTime = Get-Date
"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Import dbatools module.."
Import-Module dbatools

$ErrorActionPreference = "Stop"

if ([String]::IsNullOrEmpty($SqlCredential)) {
    "Kindly provide `$SqlCredential " | Write-Error
}

$loops = 1..$($NoOfThreads*$NoOfIterations)

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Using ForEach-Object, open $NoOfThreads parallel threads with $NoOfIterations iterations on each..."
$jobs = @() 
$jobs += $loops | ForEach-Object -Parallel {
    $SqlInstance = $Using:SqlInstance
    $Database = $Using:Database
    $SqlCredential = $Using:SqlCredential
    $DelayBetweenQueriesMS = $Using:DelayBetweenQueriesMS
    
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

    if (($id2 % 2) -eq 0) {
        # 2/3 of the workload is reports against the audit table
        if ($id1 % 2 -eq 0) {
            $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_AuditReport @TableName = 'Badges', @StartDate = '2018/01/01', @EndDate = '2018/12/31';"
        }
        else {
            $r = Invoke-DbaQuery -SqlInstance $con -Query usp_AuditReport -CommandType StoredProcedure -SqlParameter `
                        @{ TableName = 'Comments'; FieldName = 'Text'; StartDate = '2018/01/01'; EndDate = '2018/12/31' }
        }
    }
    elseif (($id1 % 13) -eq 12) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_VotesDelete $id1, $id2;"
    }
    elseif (($id1 % 13) -eq 11) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_UsersDelete $id1, $id2;"
    }
    elseif (($id1 % 13) -eq 10) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_PostsDelete $id1, $id2;"
    }
    elseif (($id1 % 13) -eq 9) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_CommentDelete $id1, $id2;"
    }
    elseif (($id1 % 13) -eq 8) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_BadgeDelete $id1, $id2;"
    }
    elseif (($id1 % 13) -eq 7) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_VoteDownComment $id1, $id2;"
    }
    elseif (($id1 % 13) -eq 6) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_VoteUpComment $id1, $id2;"
    }
    elseif (($id1 % 13) -eq 5) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_PostViewed $id1, $id2;"
    }
    elseif (($id1 % 13) -eq 4) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_VoteDownPost $id1, $id2;"
    }
    elseif (($id1 % 13) -eq 3) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_VoteUpPost $id1, $id2;"
    }
    elseif (($id1 % 13) -eq 2) {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_UserUpdateProfile @UserId = $id1, @Age = 21, @DisplayName = 'John Malkovich', @Location = 'Mertin-Flemmer Building, New York, NY', @WebsiteUrl = 'https://www.youtube.com/watch?v=Q6Fuxkinhug', @AboutMe = 'He''s very well respected. That jewel thief movie, for example. The point is that this is a very odd thing, supernatural, for lack of a better word. It raises all sorts of philosophical questions about the nature of self, about the existence of the soul. Am I me? Is Malkovich Malkovich? Was the Buddha right, is duality an illusion? Do you realize what a metaphysical can of worms this portal is? I don''t think I can go on living my life as I have lived it.';"
    }
    else {
        $r = Invoke-DbaQuery -SqlInstance $con -Query "EXEC usp_UserLogin @UserId = $id1"
    }

    $r = Invoke-DbaQuery -SqlInstance $con -Query "WHILE (@@TRANCOUNT > 0) BEGIN COMMIT	END"

    Start-Sleep -Milliseconds $DelayBetweenQueriesMS
} -ThrottleLimit $NoOfThreads -AsJob

$jobs | Receive-Job -Wait
$jobs | Remove-Job -Force

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Finished execution."

$endTime = Get-Date

$elapsedTime = New-TimeSpan -Start $startTime -End $endTime

"Total time taken = $("{0:N0}" -f $elapsedTime.TotalHours) hours $($elapsedTime.Minutes) minutes $($elapsedTime.Seconds) seconds" | Write-Host -ForegroundColor Yellow


<#
Start-Process pwsh

cd $env:USERPROFILE\documents\Lab-Load-Generator\
#$SqlCredential = Get-Credential -UserName 'SQLQueryStress' -Message 'SQLQueryStress'

cls
Import-Module dbatools;
./Invoke-ServerLab5.ps1 -SqlInstance SqlPractice -SqlCredential $SqlCredential
#>