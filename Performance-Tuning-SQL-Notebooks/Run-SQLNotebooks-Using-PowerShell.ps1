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
# Activity 01 -> Rename sample files to new date
# ---------------------------------------------------------
if($RenameFiles) { # We don't need renaming of file
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Renaming files from '$ExistingFileNamePattern' to '$NewFileNamePattern'.."

    $files2Rename = @()
    $files2Rename += Get-ChildItem -Path $SQLNotebookPath | ? {$_.Name -match "$ExistingFileNamePattern" }
    if($files2Rename.Count -eq 0) {
        "No files found to rename." | Write-Error
    }

    foreach($file in $files2Rename) {
        $newName = $file.Name -replace $ExistingFileNamePattern, $NewFileNamePattern
        "`t$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Renaming '$($file.Name)' to '$newName'" | Write-Host -ForegroundColor Cyan
        $file | Rename-Item -NewName $newName
    }
}
# ======================== END ============================

# ======================== BEGIN ==========================
# Activity 02 -> Execute all SQLNotebooks
# ---------------------------------------------------------
if($ExecuteSQLNotebooks) 
{
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Find all sample SQLNotebooks.."
    $sqlNoteBooksOnPath = @()
    if([String]::IsNullOrEmpty($StartWithFile)) {
        $sqlNoteBooksOnPath += Get-ChildItem -Path $SQLNotebookPath -Name *.ipynb `
                                -Recurse -File -Include "*$ExistingFileNamePattern*" | Sort-Object
    }
    else {
        $sqlNoteBooksOnPath += Get-ChildItem -Path $SQLNotebookPath -Name *.ipynb `
                                -Recurse -File -Include "*$ExistingFileNamePattern*" | 
                                Sort-Object | Where-Object {$_ -ge $StartWithFile}
    }

    if($sqlNoteBooksOnPath.Count -eq 0) {
        "No sample SQLNotebook files found for execution." | Write-Error
    }
    else {
        "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "$($sqlNoteBooksOnPath.Count) sample SQLNotebooks found."
    }

    $counter = 1
    foreach($noteBook in $sqlNoteBooksOnPath) 
    {
        $newName = $noteBook -replace $ExistingFileNamePattern, $NewFileNamePattern
        $outputFolder = Join-Path $SQLNotebookPath $($today.ToString("yyyy-MM-dd HHmm"))

        if( -not (Test-Path $outputFolder) ) {
            New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
        }

        $sampleNoteBook = Join-Path $SQLNotebookPath $noteBook
        $outputNoteBook = Join-Path $outputFolder $newName

        "`t$(Get-Date -Format yyyyMMMdd_HHmm) {0,-6} {1}" -f 'INFO:', "Working on $counter/$($sqlNoteBooksOnPath.Count) => '$outputNoteBook'.."
        Invoke-SqlNotebook -ServerInstance $SqlInstance -Database master `
                            -InputFile $sampleNoteBook -OutputFile $outputNoteBook `
                            -Force -Credential $SqlCredential | Out-Null
        $counter += 1
        #return
    }
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
.\Run-SQLNotebooks-Using-PowerShell.ps1 @params
#>