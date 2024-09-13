[CmdletBinding()]
Param (
  [Parameter(Mandatory = $false)]
  [String]$SqlLogin = 'sa',
  [Parameter(Mandatory = $false)]
  [String]$SqlLoginPassword = '',
  [Parameter(Mandatory = $false)]
  [String]$SqlInstance = 'localhost',
  [Parameter(Mandatory=$false)]
  [String]$Database = 'DBA',
  [Parameter(Mandatory=$false)]
  [String[]]$Table = @('dbo.disk_space','dbo.wait_stats'),
  [Parameter(Mandatory=$false)]
  [String]$ScriptOutResultFile = 'C:\temp\export.sql'
)

if ([String]::IsNullOrEmpty($SqlLoginPassword)) {
  $SqlLoginPassword = Read-Host "Enter [$SqlLogin] login password"
}

[securestring]$secStringPassword = ConvertTo-SecureString $SqlLoginPassword -AsPlainText -Force
[pscredential]$sqlCredential = New-Object System.Management.Automation.PSCredential $SqlLogin, $secStringPassword


$options = New-DbaScriptingOption
$options.ScriptSchema = $true
$options.IncludeDatabaseContext  = $true
$options.IncludeHeaders = $false
$Options.NoCommandTerminator = $false
$Options.ScriptBatchTerminator = $true
$Options.AnsiFile = $true

$tableObjects = Get-DbaDbTable -SqlInstance $SqlInstance -Database $Database -Table $Table -SqlCredential $sqlCredential -ErrorAction Stop
$tableObjects.Indexes | Export-DbaScript -FilePath $ScriptOutResultFile -ScriptingOptionsObject $options

