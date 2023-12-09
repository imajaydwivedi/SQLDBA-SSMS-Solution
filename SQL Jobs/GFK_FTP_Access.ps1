$env:PSModulePath = $env:PSModulePath + ";" + "C:\Program Files\WindowsPowerShell\Modules;C:\Windows\system32\WindowsPowerShell\v1.0\Modules\;C:\Program Files\MVPSI\Modules\";

Import-Module PSFTP

$returnCode = 0;
try
{

$FTPServer = 'ftp://ftp.somewebsite.com'
$FTPUsername = 'SomeUserName'
$FTPPassword = 'SomeStringPassword'
$dbServer = 'DatabaseServerName'
$dbName = 'DatabaseName'
$FTPSecurePassword = ConvertTo-SecureString -String $FTPPassword -asPlainText -Force
$FTPCredential = New-Object System.Management.Automation.PSCredential($FTPUsername,$FTPSecurePassword)

Set-FTPConnection -Credentials $FTPCredential -Server $FTPServer -Session MyTestSession -UsePassive | Out-Null
$Session = Get-FTPConnection -Session MyTestSession 

$ftpFiles = Get-FTPChildItem -Session $Session #-Path /TestRootDir -Recurse -Depth 2 
$ftpFiles_contso_CE_WORLD = $ftpFiles | Where-Object {$_.Name -match "contso_CE_WORLD_[A-Za-z]{3}\d{2}_[A-Za-z]{3}\d{2}\.xlsx"}
$month_enum = [Ordered]@{'JAN' = 1; 'FEB' = 2; 'MAR' = 3; 'APR' = 4; 'MAY' = 5; 'JUN' = 6; 'JUL' = 7; 'AUG' = 8; 'SEP' = 9; 'OCT' = 10; 'NOV' = 11; 'DEC' = 12}
$Files_contsoCeWorld = @()
foreach($file in $ftpFiles_contso_CE_WORLD)
{
    $filename = $file.Name;
    if($filename -match "contso_CE_WORLD_(?'Month'[A-Za-z]{3})(?'Year'\d{2})_[A-Za-z]{3}\d{2}\.xlsx")
    {
        $year = $Matches['Year'] 
        $month = $Matches['Month']
        $fileInfo = [ordered]@{
                    'Name' = $filename
                    'FullName' = $file.FullName
                    'Year' = $year
                    'Month' = $month_enum["$($month)"]
                }
        $fileInfoObj = New-Object -TypeName psobject -Property $fileInfo;
        $Files_contsoCeWorld += $fileInfoObj
    }
}

$tsqlQuery = @"
select top 1 SourceFile from [dbo].[contso_CE_WORLD] o 
where o.CollectionTime = (select max(i.CollectionTime) from [dbo].[contso_CE_WORLD] i)
"@
$queryResult = Invoke-Sqlcmd -ServerInstance $dbServer -Database $dbName -Query $tsqlQuery | Select-Object -ExpandProperty SourceFile;
$SourceFile = $queryResult.Substring($queryResult.LastIndexOf('\')+1);
if (-not ([string]::IsNullOrEmpty($tsqlQuery))) 
{
    if ($SourceFile -match "contso_CE_WORLD_(?'Month'[A-Za-z]{3})(?'Year'\d{2})_[A-Za-z]{3}\d{2}\.xlsx")
    {
        $SourceFile_Year = $Matches['Year']
        $SourceFile_Month = $month_enum["$($Matches['Month'])"]
    }
}

$Files_contsoCeWorld_ToApply = $Files_contsoCeWorld | Where-Object {$_.Year -ge $SourceFile_Year -and $_.Month -gt $SourceFile_Month} | Sort-Object -Property Year, Month;

# Remove old files from disk
Get-ChildItem -Path C:\temp | Where-Object {$_.Name -like '*_contso_CE_WORLD_*.xlsx'} | Remove-Item;
foreach($file in $Files_contsoCeWorld_ToApply)
{
    $rs = Get-FTPItem -Session $Session -Path $file.FullName -LocalPath C:\temp -Overwrite
    $filepath = 'C:\temp\'+$file.Name;
    if([System.IO.File]::Exists($filepath)) {
        Rename-Item -Path $filepath -NewName "20$($file.Year)$('{0:d2}' -f $file.Month)_$($file.Name)"
    }
}

}
catch {
    $returnCode = 1;
    Write-Host "Some error occurred: " -ForegroundColor Red
    Write-Host $_
}
finally {
    #powershell.exe -ExecutionPolicy Bypass .  'E:\MSSQL15.MSSQLSERVER\GFK_FTP_Access.ps1';
    exit $returnCode
}
