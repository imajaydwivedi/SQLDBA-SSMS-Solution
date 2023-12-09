[CmdletBinding()]
Param (
    $DistributorIP = 'DistributorIP',
    $DistributionDb = 'distribution',
    $DbaDatabase = 'DBA',
    $ReplTokenTableName = '[dbo].[repl_token_header]',
    $ReplTokenErrorTableName = '[dbo].[repl_token_insert_log]'
)

<# ****************************************************************************#
## ************** Validate Replication Health using Tracer Tokens *************#
## *************************************************************************** #>
"{0} {1,-7} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Get distributor [$DistributorIP] credentials from RegisteredServers List" | Write-Output
$DistributorConfig = Get-DbaRegisteredServer | ? {$_.ServerName -eq $DistributorIP} | Select-Object -First 1;
$Distributor = $DistributorConfig.ConnectionString | Connect-DbaInstance

# Local variables
$ErrorActionPreference = 'Stop';
$startTime = Get-Date
$Dtmm = $startTime.ToString('yyyy-MM-dd HH.mm.ss')

# Extract Credentials
$distributorConString = ($DistributorConfig.ConnectionString).Split(';');
$sqlUser = ($distributorConString[1] -split '=')[1]
$sqlUserPassword = ConvertTo-SecureString -String $(($distributorConString[2] -split '=')[1].Replace('"','')) -AsPlainText -Force
$sqlCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sqlUser, $sqlUserPassword

# Find all publications
$tsqlGetPublications = @"
IF OBJECT_ID('tempdb..#publications') IS NOT NULL
	DROP TABLE #publications;
select srv.name as publisher, pl.publisher_id, pl.publisher_db, pl.publication, pl.publication_id, 
		pl.publication_type, case pl.publication_type when 0 then 'Transactional' when 1 then 'Snapshot' when 2 then 'Merge' else 'No idea' end as publication_type_desc, 
		pl.immediate_sync, pl.allow_pull, pl.allow_push, pl.description,
		pl.vendor_name, pl.sync_method, pl.allow_initialize_from_backup
into #publications
from dbo.MSpublications pl (nolock) join sys.servers srv on srv.server_id = publisher_id
order by srv.name, pl.publisher_db;

if object_id('tempdb..#subscriptions') is not null
	drop table #subscriptions;
select distinct srv.name as subscriber, sub.subscriber_id, sub.subscriber_db, 
		sub.subscription_type, case sub.subscription_type when 0 then 'Push' when 1 then 'Pull' else 'Anonymous' end as subscription_type_desc,
		sub.publication_id, sub.publisher_db, 
		sub.sync_type, (case sub.sync_type when 1 then 'Automatic' when 2 then 'No synchronization' else 'No Idea' end) as sync_type_desc, 
		sub.status, (case sub.status when 0 then 'Inactive' when 1 then 'Subscribed' when 2 then 'Active' else 'No Idea' end) as status_desc
into #subscriptions
from dbo.MSsubscriptions sub (nolock) join sys.servers srv on srv.server_id = sub.subscriber_id
where sub.subscriber_id >= 0;

select pl.publisher, pl.publisher_db, pl.publication, pl.publication_id, pl.publication_type_desc, sb.subscriber, sb.subscriber_db, sb.subscription_type_desc, sb.sync_type_desc, sb.status_desc
from #publications pl join #subscriptions sb on sb.publication_id = pl.publication_id and sb.publisher_db = pl.publisher_db
order by pl.publisher, pl.publisher_db, sb.subscriber, sb.subscriber_db, pl.publication;
"@

"{0} {1,-7} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Get publication list for distributor [$DistributorIP]" | Write-Output
$resultGetPublications = Invoke-DbaQuery -SqlInstance $Distributor -Database $DistributionDb -Query $tsqlGetPublications
#$resultGetPublications | ogv -Title "All publications"

$publishers = $resultGetPublications | Select-Object -ExpandProperty publisher -Unique

# Insert tracer token for each publisher
$tsqlInsertToken = @"
declare @tokenID int;
-- Insert a new tracer token in the publication database.
EXEC sys.sp_posttracertoken 
  @publication = @p_publication,
  @tracer_token_id = @tokenID OUTPUT;

SELECT [publisher] = @p_publisher, [publisher_db] = db_name(), [publication] = @p_publication,
        [publication_id] = @p_publication_id, [token_id] = @tokenID, [collection_time] = sysutcdatetime(), 
        [is_processed] = 0;

"@

"{0} {1,-7} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Insert tracer token using [sp_posttracertoken]" | Write-Output
[System.Collections.ArrayList]$tokenInserted = @()
$tokenInsertFailure = @()
foreach($srv in $publishers)
{
    "{0} {1,-7} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Post token on Publications of [$srv]" | Write-Output
    $srvPublications = $resultGetPublications | Where-Object {$_.publisher -eq $srv}
    #$pubSrvObj = Connect-DbaInstance -SqlInstance $srv -SqlCredential $sqlCredential
    $pubSrvObj = Get-DbaRegisteredServer -Name $srv | Connect-DbaInstance
    foreach($pub in $srvPublications)
    {
        $params = @{ p_distributor = $DistributorIP;
                     p_publisher = $srv;
                     p_publication = $($pub.publication); 
                     p_publication_id =$($pub.publication_id);
                   }

        try {
            $resultInsertToken = Invoke-DbaQuery -SqlInstance $pubSrvObj -Database $pub.publisher_db -Query $tsqlInsertToken `
                                            -SqlParameters $params -EnableException
            $tokenInserted.Add($resultInsertToken) | Out-Null
        }
        catch {
            $err = $_
            $tokenInsertFailure += (New-Object psobject -Property @{CollectionTimeUTC = $startTime.ToUniversalTime(); Distributor = $DistributorIP; Publisher = $srv; PublisherDb = $pub.publisher_db; Publication = $pub.publication; ErrorMessage = $err.ToString()})
            "ERROR => $_" | Write-Output
        }
    }
}

"{0} {1,-7} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Populate [$DistributorIP].[$DbaDatabase].$ReplTokenTableName with tokens.." | Write-Output
#$tokenInserted | ogv -Title "Tokens inserted"
$tokenInserted | Write-DbaDbTableData -SqlInstance $DistributorIP -SqlCredential $sqlCredential -Database $DbaDatabase -Table $ReplTokenTableName -EnableException

"{0} {1,-7} {2}" -f "($((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))","(INFO)","Populate [$DistributorIP].[$DbaDatabase].$ReplTokenErrorTableName with errors.." | Write-Output
#$tokenInsertFailure | ogv
$tokenInsertFailure | Write-DbaDbTableData -SqlInstance $DistributorIP -SqlCredential $sqlCredential -Database $DbaDatabase -Table $ReplTokenErrorTableName -EnableException

