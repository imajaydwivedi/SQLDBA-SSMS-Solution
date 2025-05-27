[CmdletBinding()]
Param (
  [Parameter(Mandatory = $false)]
  [String]$SqlLogin = 'sa',
  [Parameter(Mandatory = $false)]
  [String]$SqlLoginPassword,
  [Parameter(Mandatory = $false)]
  [String]$SourceSqlInstance = 'localhost',
  [Parameter(Mandatory = $false)]
  [String[]]$DestinationSqlInstance = '21L-LTPABL-1187'
)

if ([String]::IsNullOrEmpty($SqlLoginPassword)) {
  $SqlLoginPassword = Read-Host "Enter [$SqlLogin] login password"
}

[securestring]$secStringPassword = ConvertTo-SecureString $SqlLoginPassword -AsPlainText -Force
[pscredential]$sqlCredential = New-Object System.Management.Automation.PSCredential $SqlLogin, $secStringPassword

Copy-DbaAgentJob -Source $SourceSqlInstance -Destination $DestinationSqlInstance -SourceSqlCredential $sqlCredential -DestinationSqlCredential $sqlCredential

