/*	************************************************************************************************
*	01) Powershell=> Execute TSQL Code against every ServerInstance, and get result in Out-GridView
*	***********************************************************************************************/
$sqlQuery = @"
select i.InstanceName
from Info.Instance as i
go
"@;

$qFile = 'C:\Users\adwivedi\Documents\WindowsPowerShell\Modules\SQLDBATools\SQLQueries\__06_Setup [DBA] db.sql';

$qResult = (Invoke-Sqlcmd -ServerInstance $InventoryInstance -Database $InventoryDatabase -Query $sqlQuery | 
                Where-Object {[String]::IsNullOrEmpty($_.InstanceName) -eq $false} | Select-Object -ExpandProperty InstanceName);

$finalResult = @();
foreach($ServerInstance in $qResult)
{
    try 
    {
        $r = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database master -Query 'exec dba..[usp_SecurityCheck]' -ErrorAction SilentlyContinue |
                Select-Object @{l='SqlInstance';e={$ServerInstance}}, principal_name, type_desc, role_permission, roleOrPermission, @{l='CollectionTime';e={(Get-Date).ToString("yyyy-MM-dd HH:mm:ss")}};
        $finalResult += $r;     
    }
    catch 
    {
        Write-Host "Error($ServerInstance): Failure while executing SQL code from file $qFile" -ForegroundColor Red;
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName

        @"

$FailedItem => 
    $ErrorMessage
====================================
"@
    }
}

$finalResult | Out-GridView
$finalResult | Export-Excel -Path 'C:\temp\SQLDBATools\usp_SecurityCheck__30Apr2018.xlsx'

/*	************************************************************************************************
*	02) Powershell=> Execute TSQL Script File against every ServerInstance
*	***********************************************************************************************/

$sqlQuery = @"
select s.ServerID, s.ServerName, s.EnvironmentType, s.DNSHostName, s.FQDN, s.IPAddress, 
		s.Domain, s.OperatingSystem, s.SPVersion, s.IsVM, s.Manufacturer, s.Model, s.RAM, 
		s.CPU, s.CollectionTime, s.GeneralDescription,
		i.InstanceID, i.InstanceName, i.InstallDataDirectory, i.Version, i.Edition, i.ProductKey, 
		i.IsClustered, i.IsCaseSensitive, i.IsHadrEnabled, i.IsDecommissioned, i.IsPowerShellLinked
from Info.Server as s
left join
	Info.Instance as i
	on i.FQDN = s.FQDN
go
"@;

$qFile = 'C:\Users\adwivedi\Documents\WindowsPowerShell\Modules\SQLDBATools\SQLQueries\__06_Setup [DBA] db.sql';

$qResult = (Invoke-Sqlcmd -ServerInstance $InventoryInstance -Database $InventoryDatabase -Query $sqlQuery | 
                Where-Object {[String]::IsNullOrEmpty($_.InstanceName) -eq $false} | Select-Object -ExpandProperty InstanceName);

foreach($ServerInstance in $qResult)
{
    try 
    {
        $qResult = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database master -InputFile $qFile -ErrorAction SilentlyContinue;
    }
    catch 
    {
        Write-Host "Error($ServerInstance): Failure while executing SQL code from file $qFile" -ForegroundColor Red;
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName

        @"

$FailedItem => 
    $ErrorMessage
====================================
"@
    }
}