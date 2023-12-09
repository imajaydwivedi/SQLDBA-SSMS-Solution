Import-Module dbatools;

$ProdServers = Get-Content -Path 'C:\temp\SQLDBATools\Prod_Servers.txt';
$NonProdServers = Get-Content -Path 'C:\temp\SQLDBATools\NonProd_Servers.txt';

$sqlQuery = @"
select	@@servername as srvName, mf.database_id, DB_NAME(mf.database_id) as dbName, DATABASEPROPERTYEX(DB_NAME(mf.database_id),'Status') as dbStatus, DATABASEPROPERTYEX(DB_NAME(mf.database_id),'IsInStandBy') as IsInStandBy, cast((d.Pages*8.0)/1024 as decimal(20,2)) as [dbName(MB)], mf.type_desc, mf.physical_name, 
		size as FileSizePages, (size*8.0) as [FileSize(KB)], cast((size*8.0)/1024 as decimal(20,2)) as [FileSize(MB)], cast((size*8.0)/1024/1024 as decimal(20,2)) as [FileSize(GB)]
from	sys.master_files as mf
join (
		select mfi.database_id, SUM(mfi.size) as Pages
		from sys.master_files as mfi
		group by mfi.database_id
) as d
	on	mf.database_id = d.database_id
"@;

$nonAccessibleServers = @();
$queryOutput = @();
foreach($srv in $ProdServers)
{
    $Error.Clear();
    try {
        $queryOutput += Invoke-Sqlcmd2 -ServerInstance $srv -Query $sqlQuery -ErrorAction Stop;
    }
    catch {
        $nonAccessibleServers += $srv;
        Write-Host "Server $srv";
        Write-Host ($error) -ForegroundColor Red;
    }
}

$queryOutput | Export-Excel -Path 'C:\temp\DB_and_Files_Size.xlsx' -WorkSheetname 'Prod';


#Invoke-Sqlcmd2 -ServerInstance $ProdServers -Query $sqlQuery | Out-GridView

$queryOutput = @();
foreach($srv in $NonProdServers)
{
    $Error.Clear();
    try {
        $queryOutput += Invoke-Sqlcmd2 -ServerInstance $srv -Query $sqlQuery -ErrorAction Stop;
    }
    catch {
        $nonAccessibleServers += $srv;
        Write-Host "Server $srv";
        Write-Host ($error) -ForegroundColor Red;
    }
}

$queryOutput | Export-Excel -Path 'C:\temp\DB_and_Files_Size.xlsx' -WorkSheetname 'Non-Prod';
$nonAccessibleServers | Export-Excel -Path 'C:\temp\DB_and_Files_Size.xlsx' -WorkSheetname 'Non-Accessible servers';

$nonAccessibleServers | foreach {

    try {
        #Test-DbaConnection $_ | Out-File -FilePath C:\temp\DB_and_Files_Size.txt -Append;
        Test-Connection $_ -Count 2;
    }
    catch {
        Write-Host "------------------------------------------";
        Write-Host "Server $srv";
        Write-Host ($error) -ForegroundColor Red;
    }
}

#Write-Output "exec xp_cmdshell 'sqlcmd -S $_ -Q `"select @@servername;`"' " ;

