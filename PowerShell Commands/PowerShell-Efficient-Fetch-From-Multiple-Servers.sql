#$personal = Get-Credential -UserName 'sa' -Message 'Personal'

cls
$InventoryServer = '$InventoryServer'
$InventoryDatabase = 'DBA'
$CredentialManagerDatabase = 'DBA_Inventory'
$ServersListFile = "D:\GitHub-Personal\SQLMonitor\Work\vipin-servers-list.txt"
$SQLQuery2Execute = @"
DECLARE @Domain NVARCHAR(255);
begin try
	EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', 'SYSTEM\CurrentControlSet\services\Tcpip\Parameters', N'Domain',@Domain OUTPUT;
end try
begin catch
	print 'some erorr accessing registry'
end catch

select	[SQLInstance] = @sql_instance,
        [domain] = DEFAULT_DOMAIN(),
		[domain_reg] = @Domain,
		[ip] = CONNECTIONPROPERTY('local_net_address'),
		[@@SERVERNAME] = @@SERVERNAME,
		[MachineName] = serverproperty('MachineName'),
		[ServerName] = serverproperty('ServerName'),
		[host_name] = SERVERPROPERTY('ComputerNamePhysicalNetBIOS'),
		[sql_version] = @@VERSION,
		[service_name_str] = servicename,
		[service_name] = case	when @@servicename = 'MSSQLSERVER' and servicename like 'SQL Server (%)' then 'MSSQLSERVER'
								when @@servicename = 'MSSQLSERVER' and servicename like 'SQL Server Agent (%)' then 'SQLSERVERAGENT'
								when @@servicename <> 'MSSQLSERVER' and servicename like 'SQL Server (%)' then 'MSSQL$'+@@servicename
								when @@servicename <> 'MSSQLSERVER' and servicename like 'SQL Server Agent (%)' then 'SQLAgent'+@@servicename
								else 'MSSQL$'+@@servicename end,
		[instance_name] = @@servicename,
		service_account,
		SERVERPROPERTY('Edition') AS Edition,
		SERVERPROPERTY('ProductVersion') AS ProductVersion,
		SERVERPROPERTY('ProductLevel') AS ProductLevel
		--,instant_file_initialization_enabled
		--,*
from sys.dm_server_services 
where servicename like 'SQL Server (%)'
or servicename like 'SQL Server Agent (%)'
"@

$startTime = Get-Date
"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "[Connect-DbaInstance] Create connection for InventoryServer '$InventoryServer'.."
$conInventoryServer = Connect-DbaInstance -SqlInstance $InventoryServer -Database $InventoryDatabase -ClientName "Get-FailedLogins.ps1" `
                                                    -TrustServerCertificate -ErrorAction Stop -SqlCredential $personal

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Fetch [LinkAdmin] password from Credential Manager [$InventoryServer].[$CredentialManagerDatabase].."
$getCredential = @"
/* Fetch Credentials */
declare @password varchar(256);
exec dbo.usp_get_credential 
		@server_ip = '*',
		@user_name = 'sa',
		@password = @password output;
select @password as [password];
"@
[string]$linkAdminPassword = Invoke-DbaQuery -SqlInstance $conInventoryServer -Database $CredentialManagerDatabase -Query $getCredential | 
                                    Select-Object -ExpandProperty password -First 1

"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Create LinkAdmin credential from fetched password.."
[string]$linkAdminUser = 'sa'
[securestring]$secStringPassword = ConvertTo-SecureString $linkAdminPassword -AsPlainText -Force
[pscredential]$linkAdminCredential = New-Object System.Management.Automation.PSCredential $linkAdminUser, $secStringPassword

$allServersList = @()
$allServersList += Get-Content $ServersListFile

# Execute SQL files & SQL Query
$successServers = @()
[System.Collections.ArrayList]$failedServers = @()
[System.Collections.ArrayList]$queryResult = @()

foreach($srv in $allServersList)
{
    "Working on [$srv]" | Write-Host -ForegroundColor Cyan

    try {
        Invoke-DbaQuery -SqlInstance $srv -Database master -Query $SQLQuery2Execute -SqlParameter @{ sql_instance = $srv } -SqlCredential $linkAdminCredential -EnableException `
                    -As PSObject | % {$queryResult.Add($_)|Out-Null}
        
        $successServers += $sqlInstance
    }
    catch {
        $errMessage = $_
        $obj = [PSCustomObject]@{
            SQLInstance  = $srv
            Error = $errMessage
        }
        $failedServers.Add($obj)|Out-Null

        $errMessage.Exception | Write-Host -ForegroundColor Red
        "`n"
    }
}


$failedServers | ogv -Title "Failed"
$successServers | ogv -Title "Successful"

$outputExcelFile = "$($env:USERPROFILE)\Downloads\queryResult_$($startTime.ToString('yyyy-MM-dd HH.mm.ss')).xlsx"
$queryResult | Export-Excel $outputExcelFile -WorksheetName "Result"
$failedServers | Export-Excel $outputExcelFile -WorksheetName "Failed"

$outputExcelFile