--	01) Script Out User Permissions
Import-Module dbatools;
Export-DbaUser -SqlInstance YourDbServerName -Database Logging -User YourAppUser01

--	01) Script Out User Permissions
Import-Module dbatools;
Export-DbaUser -SqlInstance YourDbServerName -Database Logging -User YourAppUser02

--	02) Script Out User Permissions
$scriptPath = Get-DatabasePermissions -SqlInstance YourDbServerName;
$server = 'servername'
$files = Get-ChildItem $scriptPath;

foreach($file in $files) {
    $dbName = $file.BaseName;
    $fileName = $file.FullName;
    Write-Host "Writing to database '$dbName'" -ForegroundColor Black -BackgroundColor White;
    Invoke-DbaQuery -SqlInstance $server -Database $dbName -File $fileName;
}