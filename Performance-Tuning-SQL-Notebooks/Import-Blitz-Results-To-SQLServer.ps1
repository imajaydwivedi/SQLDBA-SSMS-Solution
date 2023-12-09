[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [String]$SQLNotebookPath,
    [Parameter(Mandatory=$true)]
    [String]$SqlInstance,
    [Parameter(Mandatory=$false)]
    [String]$ExistingFileNamePattern = 'WeekDay-MonthDay',
    [Parameter(Mandatory=$false)]
    [String]$NewFileNamePattern,
    [Parameter(Mandatory=$false)]
    [PSCredential]$SqlCredential,
    [Switch]$RenameFiles,
    [switch]$ExecuteSQLNotebooks,
    [switch]$ImportBlitzIndexData,
    [String]$StartWithFile
)
"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Import dbatools.."
Import-Module dbatools
$ErrorActionPreference = "STOP"

# Declare local variables
$today = Get-Date
if([String]::IsNullOrEmpty($NewFileNamePattern)) {
    $NewFileNamePattern = "$($today.ToString('ddd'))-$($today.ToString('MMM'))$($today.ToString('dd'))"
}

# Validate credentials
if($ExecuteSQLNotebooks) {
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Validate SQL Credentails.."
    Invoke-DbaQuery -SqlInstance $SqlInstance -Query 'select @@version as vrsn' -SqlCredential $SqlCredential -EnableException | Out-Null
}

# Install PowerShellNotebook
"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Import PowerShellNotebook module.."

# Validate SQLNotebookPath
if([String]::IsNullOrEmpty($SQLNotebookPath)) {
    $SQLNotebookPath = $PSScriptRoot
}

if([String]::IsNullOrEmpty($SQLNotebookPath)) {
    "Kindly provide SQLNotebookPath parameter." | Write-Error
}
else {
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "`$SQLNotebookPath => '$SQLNotebookPath'"
}

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "`$ExistingFileNamePattern => '$ExistingFileNamePattern'"
"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "`$NewFileNamePattern => '$NewFileNamePattern'"

# ======================== BEGIN ==========================
# Activity 03 -> Import BlitzIndex to SQL Tables
# ---------------------------------------------------------
#$personal = Get-Credential -UserName 'sa' -Message 'Personal'
if($ImportBlitzIndexData)
{
    $Server = 'SQLPractice'
    $IndexSummaryFile = 'D:\SQLPractice\sp_BlitzIndex-Summary-Fri-Aug26.xlsx'
    $IndexDetailedFile = 'D:\SQLPractice\sp_BlitzIndex-Detailed-Fri-Aug26.xlsx'

    Import-Excel $IndexSummaryFile | Write-DbaDbTableData -SqlInstance $Server -Database 'DBA' -Table 'BlitzIndex_Summary_Aug26' -SqlCredential $personal -AutoCreateTable
    Import-Excel $IndexDetailedFile | Write-DbaDbTableData -SqlInstance $Server -Database 'DBA' -Table 'BlitzIndex_Detailed_Aug26' -SqlCredential $personal -AutoCreateTable


    EXEC sp_rename 'dbo.ErrorLog.ErrorTime', 'ErrorDateTime', 'COLUMN';
}
# ======================== END ============================


<#
cls
cd D:\GitHub-Office\DBA-SRE\YourServerName\

Import-Module dbatools
$ErrorActionPreference = "STOP"

#$sqlCredential = Get-Credential -UserName 'SomeLogin' -Message 'SQL Credentials'
$params = @{
    SqlInstance = 'YourServerName'
    SqlCredential = $sqlCredential
    #ExistingFileNamePattern = 'Thu-Sep29'
    #NewFileNamePattern = 'WeekDay-MonthDay'
    ExecuteSQLNotebooks = $true
    #RenameFiles = $true
    #StartWithFile = 'sp_BlitzFirst-SinceStartup'
}
.\Import-Blitz-Results-To-SQLServer.ps1 @params
#>