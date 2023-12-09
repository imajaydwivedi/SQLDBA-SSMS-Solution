https://sqlrambling.net/2016/12/01/ssisdb-and-catalog-part-3-copying-a-package-between-servers/

Param($SQLInstance = "SourceSqlInstance")
add-pssnapin sqlserverprovidersnapin100 -ErrorAction SilentlyContinue
add-pssnapin sqlservercmdletsnapin100 -ErrorAction SilentlyContinue
cls
$Packages =  Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query "select p.name, CAST(CAST(packagedata AS VARBINARY(MAX)) AS VARCHAR(MAX)) as pkg
FROM MSDB..sysssispackages p join
msdb..sysssispackagefolders f on p.folderid = f.folderid
where f.foldername NOT LIKE 'Data Collector%'"
Foreach ($pkg in $Packages)
{
    $pkgName = $Pkg.name
    $fullfolderPath = "C:\Users\adwivedi\Documents\SSIS_Packages_DBA\$pkgName\"
    if(!(test-path -path $fullfolderPath))
    {
        mkdir $fullfolderPath | Out-Null
    }
    $pkg.pkg | Out-File -Force -encoding ascii -FilePath "$fullfolderPath\$pkgName.dtsx"
}