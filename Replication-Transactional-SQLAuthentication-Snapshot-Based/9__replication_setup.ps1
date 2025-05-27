[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)]
    [String]$DistributorServer,
    [Parameter(Mandatory=$false)]
    [String]$DistributionDatabase = 'distribution',
    [Parameter(Mandatory=$true)]
    [String]$PublisherServer,
    [Parameter(Mandatory=$true)]
    [String]$SubscriberServer,
    [Parameter(Mandatory = $true)]
    [ValidateSet('NTT', 'GPX')]
    [string]$DataCenter,
    [Parameter(Mandatory=$true)]   
    [String]$PublisherDatabase,
    [Parameter(Mandatory=$false)]
    [String]$SubsciberDatabase,
    [Parameter(Mandatory=$true)]
    [PSCredential]$SqlCredential,
    [Parameter(Mandatory=$true)]
    [String[]]$Table,
    [Parameter(Mandatory=$true)]
    [String]$ReplLoginName,
    [Parameter(Mandatory=$true)]
    [String]$ReplLoginPassword,
    [Parameter(Mandatory=$false)]
    [String]$LogReaderAgentJob,
    [Parameter(Mandatory=$false)]
    [bool]$IncludeAddDistributorScripts = $false,
    [Parameter(Mandatory=$false)]
    [bool]$IncludeDropPublicationScripts = $false,
    [Parameter(Mandatory=$false)]
    [String]$ScriptsDirectory,
    [Parameter(Mandatory=$false)]
    [String]$OutputFile,
    [Parameter(Mandatory=$false)]
    [String[]]$LoginsForReplAccess = @('sa')
)

# Declare other important variables/Parameters
[String]$dropReplPubFileName = "8__drop-replication-publication.sql"
[String]$addReplDistributorFileName = "9a__replication-add-distributor.sql"
[String]$createReplPubFileName = "9b__replication-create-publication.sql"
[String]$addReplArticlesFileName = "9c__replication-add-articles.sql"
[String]$startSnapshotAgentFileName = "9d__replication-start-snapshot-agent.sql"
[String]$CheckReplSnapshotHistoryFileName = "9e__replication-check-snapshot-history.sql"
[String]$createReplSubFileName = "9f__replication-create-subscription.sql"
[String]$getPublicationDetailsFileName = "9g__replication-get-publication-details.sql"
[String]$CheckReplDistributionHistoryFileName = "9h__replication-check-distribution-history.sql"
[String]$CheckIdentityFileName = "9i__replication-check-identity.sql"

$verbose = $false;
if ($PSBoundParameters.ContainsKey('Verbose')) { # Command line specifies -Verbose[:$false]
    $verbose = $PSBoundParameters.Get_Item('Verbose')
}

$debug = $false;
if ($PSBoundParameters.ContainsKey('Debug')) { # Command line specifies -Debug[:$false]
    $debug = $PSBoundParameters.Get_Item('Debug')
}

# Fetch allowed values dynamically
$allowedDataCenterValues = ($MyInvocation.MyCommand.Parameters['DataCenter'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }).ValidValues

# Evaluate path of ScriptsDirectory folder
if( (-not [String]::IsNullOrEmpty($PSScriptRoot)) -or ((-not [String]::IsNullOrEmpty($ScriptsDirectory)) -and $(Test-Path $ScriptsDirectory)) ) {
    if([String]::IsNullOrEmpty($ScriptsDirectory)) {
        $ScriptsDirectory = $PSScriptRoot
    }
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "`$ScriptsDirectory = '$ScriptsDirectory'"
}
else {
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'ERROR:', "Kindly provide 'ScriptsDirectory' parameter value" | Write-Host -ForegroundColor Red
    Write-Error "Stop here. Fix above issue."
}

# Construct full file path
$dropReplPubFilePath = "$ScriptsDirectory\$dropReplPubFileName"
$addReplDistributorFilePath = "$ScriptsDirectory\$addReplDistributorFileName"
$createReplPubFilePath = "$ScriptsDirectory\$createReplPubFileName"
$addReplArticlesFilePath = "$ScriptsDirectory\$addReplArticlesFileName"
$startSnapshotAgentFilePath = "$ScriptsDirectory\$startSnapshotAgentFileName"
$CheckReplSnapshotHistoryFilePath = "$ScriptsDirectory\$CheckReplSnapshotHistoryFileName"
$createReplSubFilePath = "$ScriptsDirectory\$createReplSubFileName"
$getPublicationDetailsFilePath = "$ScriptsDirectory\$getPublicationDetailsFileName"
$CheckReplDistributionHistoryFilePath = "$ScriptsDirectory\$CheckReplDistributionHistoryFileName"
$CheckIdentityFilePath = "$ScriptsDirectory\$CheckIdentityFileName"

# Trim PublisherServer
$PublisherServer = $PublisherServer.Trim()
$PublisherServerString = $PublisherServer
$Port4PublisherServer = $null
$PublisherServerWithOutPort = $PublisherServer
if($PublisherServer -match "(?'SqlInstance'.+),(?'PortNo'\d+)") {
    $Port4PublisherServer = $($Matches['PortNo']).Trim()
    $PublisherServerWithOutPort = $($Matches['SqlInstance']).Trim()
}

# Trim SubscriberServer
$SubscriberServer = $SubscriberServer.Trim()
$SubscriberServerString = $SubscriberServer
$Port4SubscriberServer = $null
$SubscriberServerWithOutPort = $SubscriberServer
if($SubscriberServer -match "(?'SqlInstance'.+),(?'PortNo'\d+)") {
    $Port4SubscriberServer = $($Matches['PortNo']).Trim()
    $SubscriberServerWithOutPort = $($Matches['SqlInstance']).Trim()
}
$tablesCount = $Table.Count

# Extract one article name & owner
$firstTable = $Table[0]
$schemaName = 'dbo'
$tableName = $firstTable.Trim()
if($firstTable -match "(?'Schema'.+)\.(?'Table'.+)") {
    $schemaName = $Matches['Schema']
    $tableName = $Matches['Table']
}


# Get connection to Distributor
$conDistributorServer = Connect-DbaInstance -SqlInstance $DistributorServer -Database $DistributionDatabase -SqlCredential $SqlCredential -ClientName "Get-PublicationDetails" -TrustServerCertificate -EncryptConnection -ErrorAction Stop -Debug:$false

if ($true)
{ 
    $sqlPublicationDetails = [System.IO.File]::ReadAllText($getPublicationDetailsFilePath)    
    $sqlPublicationDetails = $sqlPublicationDetails.Replace('@publisher_server', "'$SubscriberServerWithOutPort'")
    $sqlPublicationDetails = $sqlPublicationDetails.Replace('@publisher_db', "'$SubsciberDatabase'")
    $sqlPublicationDetails = $sqlPublicationDetails.Replace('@subscriber_server', "'$PublisherServerWithOutPort'")
    $sqlPublicationDetails = $sqlPublicationDetails.Replace('@subscriber_db', "'$PublisherDatabase'")
    $sqlPublicationDetails = $sqlPublicationDetails.Replace('@source_owner', "'$schemaName'")
    $sqlPublicationDetails = $sqlPublicationDetails.Replace('@source_object', "'$tableName'")

    $publicationDetails = @()
    $publicationDetails += $conDistributorServer | Invoke-DbaQuery -Query $sqlPublicationDetails -EnableException
}

# Compute publication name
if ($publicationDetails.Count -gt 0) {
    [String]$dataCenterCurrent = $($allowedDataCenterValues | Where-Object {$_ -ne $DataCenter})

    [String]$publicationNameCurrent = $publicationDetails[0].publication    
    [String]$PublicationNameNew = $publicationNameCurrent -replace $dataCenterCurrent, $DataCenter
}

if([String]::IsNullOrEmpty($OutputFile)) {
    #$OutputFile = "$ScriptsDirectory\Scriptout--Drop-Pub-[$publicationNameCurrent]--Create-Pub-[$PublicationNameNew].sql"
    $OutputFile = "$ScriptsDirectory\temp-output-Create-Replication-Publication.sql"
}

# Print variable values
"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "`$publicationNameCurrent = '$publicationNameCurrent'"
"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "`$PublicationNameNew = '$PublicationNameNew'"
#"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "`$LogReaderAgentJob = '$LogReaderAgentJob'"
"$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "No of Tables = '$tablesCount'"

# Initialize output file
"/* Script to create Replication */`n" | Out-File $OutputFile

# Drop Publication
if ($IncludeDropPublicationScripts) 
{
    if($verbose) {
        "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Add steps to drop existing publication.."
    }
    $dropReplPubFileContent = [System.IO.File]::ReadAllText($dropReplPubFilePath)    
    $dropReplPubFileContent = $dropReplPubFileContent.Replace("[PublisherServer]", "PublisherServer [$SubscriberServer]")
    $dropReplPubFileContent = $dropReplPubFileContent.Replace("[DistributorServer]", "DistributorServer [$DistributorServer]")
    $dropReplPubFileContent = $dropReplPubFileContent.Replace("<PublisherDbNameHere>", "$SubsciberDatabase")
    $dropReplPubFileContent = $dropReplPubFileContent.Replace("<PublicationNameHere>", "$publicationNameCurrent")
    $dropReplPubFileContent = $dropReplPubFileContent.Replace("<SubscriberServerNameHere>", "$PublisherServerWithOutPort")
    $dropReplPubFileContent = $dropReplPubFileContent.Replace("<SubscriberDbNameHere>", "$PublisherDatabase")

    $sqlDropArticleAll = ''
    foreach($tbl in $Table)
    {
        # Extract table & schema name
        $schemaName = 'dbo'
        $tableName = $tbl.Trim()
        if($tbl -match "(?'Schema'.+)\.(?'Table'.+)") {
            $schemaName = $Matches['Schema']
            $tableName = $Matches['Table']
        }

        $schemaName = $schemaName.Trim().Trim('[').Trim(']').Trim()
        $tableName = $tableName.Trim().Trim('[').Trim(']').Trim()

        $sqlDropArticle = "use [$SubsciberDatabase]"
        $sqlDropArticle += "`nexec sp_droparticle @article = N'$tableName', @publication = N'$publicationNameCurrent', @force_invalidate_snapshot = 1"
        $sqlDropArticle += "`nGO`n"

        $sqlDropArticleAll += $sqlDropArticle
    }

    #$dropReplPubFileContent = $dropReplPubFileContent.Replace("-- Execute <sp_droparticle> for each table", "$sqlDropArticleAll")

    $dropReplPubFileContent | Out-File $OutputFile -Append
}

# Add Distributor
if ($IncludeAddDistributorScripts) 
{
    if($verbose) {
        "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Add sql to configure distributor.."
    }
    $addReplDistributorFileContent = [System.IO.File]::ReadAllText($addReplDistributorFilePath)    
    $addReplDistributorFileContent = $addReplDistributorFileContent.Replace("[PublisherServer]", "PublisherServer [$PublisherServer]")
    $addReplDistributorFileContent = $addReplDistributorFileContent.Replace("[DistributorServer]", "DistributorServer [$DistributorServer]")
    $addReplDistributorFileContent = $addReplDistributorFileContent.Replace("<DistributorServerNameHere>", "$DistributorServer")
    $addReplDistributorFileContent = $addReplDistributorFileContent.Replace("<ReplLoginPasswordHere>", "$ReplLoginPassword")
    $addReplDistributorFileContent = $addReplDistributorFileContent.Replace("<DistributionDbNameHere>", "$DistributionDatabase")
    $addReplDistributorFileContent = $addReplDistributorFileContent.Replace("<PublisherServerNameHere>", "$PublisherServer")

    $addReplDistributorFileContent | Out-File $OutputFile -Append
}

# Read publication setup
if($verbose) {
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Add sql to add publication.."
}
$createReplPubFileContent = [System.IO.File]::ReadAllText($createReplPubFilePath)
$createReplPubFileContent = $createReplPubFileContent.Replace("<PublisherDbNameHere>", "$PublisherDatabase")
$createReplPubFileContent = $createReplPubFileContent.Replace("<ReplLoginNameHere>", "$ReplLoginName")
$createReplPubFileContent = $createReplPubFileContent.Replace("<ReplLoginPasswordHere>", "$ReplLoginPassword")
$createReplPubFileContent = $createReplPubFileContent.Replace("<PublisherServerNameHere>", "$PublisherServer")
$createReplPubFileContent = $createReplPubFileContent.Replace("<PublicationNameHere>", "$PublicationNameNew")
#$createReplPubFileContent = $createReplPubFileContent.Replace("<LogReaderAgentJobNameHere>", "$LogReaderAgentJob")
$createReplPubFileContent = $createReplPubFileContent.Replace("[PublisherServer]", "PublisherServer [$PublisherServer]")
$createReplPubFileContent = $createReplPubFileContent.Replace("[DistributorServer]", "DistributorServer [$DistributorServer]")

$sqlGrantPubAccessAll = ''
foreach($login in $LoginsForReplAccess)
{
    $login = $login.Trim().Trim('[').Trim(']').Trim()
    $sqlGrantPubAccess = "exec sp_grant_publication_access @publication = N'$PublicationNameNew', @login = N'$login';`n"
    $sqlGrantPubAccessAll += $sqlGrantPubAccess
}
$createReplPubFileContent = $createReplPubFileContent.Replace("-- execute sp_grant_publication_access for LoginForReplAccessHere", "$sqlGrantPubAccessAll")

$createReplPubFileContent | Out-File $OutputFile -Append

# Add articles
if($verbose) {
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Add sql to add articles.."
}
$addReplArticlesFileContentOriginal = [System.IO.File]::ReadAllText($addReplArticlesFilePath)
$addReplArticlesFileContentOriginal = $addReplArticlesFileContentOriginal.Replace("<PublicationNameHere>", "$PublicationNameNew")
$addReplArticlesFileContentOriginal = $addReplArticlesFileContentOriginal.Replace("<PublisherDbNameHere>", "$PublisherDatabase")
$addReplArticlesFileContentOriginal = $addReplArticlesFileContentOriginal.Replace("[PublisherServer]", "PublisherServer [$PublisherServer]")
$addReplArticlesFileContentOriginal = $addReplArticlesFileContentOriginal.Replace("[DistributorServer]", "DistributorServer [$DistributorServer]")

foreach($tbl in $Table)
{
    # Extract table & schema name
    $schemaName = 'dbo'
    $tableName = $tbl.Trim()
    if($tbl -match "(?'Schema'.+)\.(?'Table'.+)") {
        $schemaName = $Matches['Schema']
        $tableName = $Matches['Table']
    }

    $schemaName = $schemaName.Trim().Trim('[').Trim(']').Trim()
    $tableName = $tableName.Trim().Trim('[').Trim(']').Trim()

    #"$schemaName.$tableName"
    $addReplArticlesFileContent = $addReplArticlesFileContentOriginal.Replace("<PublishedTableNameHere>", "$tableName")
    $addReplArticlesFileContent = $addReplArticlesFileContent.Replace("<PublishedTableSchemaNameHere>", "$schemaName")  
    
    $addReplArticlesFileContent | Out-File -Append $OutputFile
}


# Start Snapshot Agent
if($verbose) {
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Add sql to start Snapshot agent.."
}
$startSnapshotAgentFileContent = [System.IO.File]::ReadAllText($startSnapshotAgentFilePath)
$startSnapshotAgentFileContent = $startSnapshotAgentFileContent.Replace("<PublicationNameHere>", "$PublicationNameNew")
$startSnapshotAgentFileContent = $startSnapshotAgentFileContent.Replace("<PublisherDbNameHere>", "$PublisherDatabase")
$startSnapshotAgentFileContent = $startSnapshotAgentFileContent.Replace("[PublisherServer]", "PublisherServer [$PublisherServer]")
$startSnapshotAgentFileContent = $startSnapshotAgentFileContent.Replace("[DistributorServer]", "DistributorServer [$DistributorServer]")

$startSnapshotAgentFileContent | Out-File -Append $OutputFile


# Check Snapshot Agent execution history
if($verbose) {
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Add sql to check Snapshot agent history.."
}
$checkReplSnapshotHistoryFileContent = [System.IO.File]::ReadAllText($CheckReplSnapshotHistoryFilePath)
$checkReplSnapshotHistoryFileContent = $checkReplSnapshotHistoryFileContent.Replace("<PublicationNameHere>", "$PublicationNameNew")
$checkReplSnapshotHistoryFileContent = $checkReplSnapshotHistoryFileContent.Replace("<PublisherDbNameHere>", "$PublisherDatabase")
$checkReplSnapshotHistoryFileContent = $checkReplSnapshotHistoryFileContent.Replace("<DistributionDbNameHere>", "$DistributionDatabase")
$checkReplSnapshotHistoryFileContent = $checkReplSnapshotHistoryFileContent.Replace("[PublisherServer]", "PublisherServer [$PublisherServer]")
$checkReplSnapshotHistoryFileContent = $checkReplSnapshotHistoryFileContent.Replace("[DistributorServer]", "DistributorServer [$DistributorServer]")
$checkReplSnapshotHistoryFileContent = $checkReplSnapshotHistoryFileContent.Replace("<TotalPublishedTablesCountHere>", "$tablesCount")

$checkReplSnapshotHistoryFileContent | Out-File -Append $OutputFile


# Add subscription
if($verbose) {
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Add sql to add subscription.."
}
$createReplSubFileContent = [System.IO.File]::ReadAllText($createReplSubFilePath)
$createReplSubFileContent = $createReplSubFileContent.Replace("<PublicationNameHere>", "$PublicationNameNew")
$createReplSubFileContent = $createReplSubFileContent.Replace("<PublisherServerNameHere>", "$PublisherServer")
$createReplSubFileContent = $createReplSubFileContent.Replace("<PublisherDbNameHere>", "$PublisherDatabase")
$createReplSubFileContent = $createReplSubFileContent.Replace("<SubscriberServerNameHere>", "$SubscriberServer")
$createReplSubFileContent = $createReplSubFileContent.Replace("<SubscriberDbNameHere>", "$SubsciberDatabase")
$createReplSubFileContent = $createReplSubFileContent.Replace("<DistributionDbNameHere>", "$DistributionDatabase")
$createReplSubFileContent = $createReplSubFileContent.Replace("[PublisherServer]", "PublisherServer [$PublisherServer]")
$createReplSubFileContent = $createReplSubFileContent.Replace("[DistributorServer]", "DistributorServer [$DistributorServer]")
$createReplSubFileContent = $createReplSubFileContent.Replace("<TotalPublishedTablesCountHere>", "$tablesCount")
$createReplSubFileContent = $createReplSubFileContent.Replace("<ReplLoginNameHere>", "$ReplLoginName")
$createReplSubFileContent = $createReplSubFileContent.Replace("<ReplLoginPasswordHere>", "$ReplLoginPassword")
$createReplSubFileContent = $createReplSubFileContent.Replace("<LogReaderAgentJobNameHere>", "$LogReaderAgentJob")

$createReplSubFileContent | Out-File -Append $OutputFile


# Check Distribution Agent execution history
if($verbose) {
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "Add sql to check Distribution agent history.."
}
$checkReplDistributionHistoryFileContent = [System.IO.File]::ReadAllText($CheckReplDistributionHistoryFilePath)
$checkReplDistributionHistoryFileContent = $checkReplDistributionHistoryFileContent.Replace("<PublicationNameHere>", "$PublicationNameNew")
$checkReplDistributionHistoryFileContent = $checkReplDistributionHistoryFileContent.Replace("<PublisherDbNameHere>", "$PublisherDatabase")
$checkReplDistributionHistoryFileContent = $checkReplDistributionHistoryFileContent.Replace("<DistributionDbNameHere>", "$DistributionDatabase")
$checkReplDistributionHistoryFileContent = $checkReplDistributionHistoryFileContent.Replace("[PublisherServer]", "PublisherServer [$PublisherServer]")
$checkReplDistributionHistoryFileContent = $checkReplDistributionHistoryFileContent.Replace("[DistributorServer]", "DistributorServer [$DistributorServer]")
$checkReplDistributionHistoryFileContent = $checkReplDistributionHistoryFileContent.Replace("<TotalPublishedTablesCountHere>", "$tablesCount")

$checkReplDistributionHistoryFileContent | Out-File -Append $OutputFile


# Check/Reseed Identity in tables
if($verbose) {
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "check/Reseed Identity in Tables.."
}
$sqlCheckIdentity = [System.IO.File]::ReadAllText($CheckIdentityFilePath)

# Loop through tables, and get comma separated list of table names without schema
$tableNamesWithoutSchema = @()
foreach($tbl in $Table)
{
    # Extract table & schema name
    $schemaName = 'dbo'
    $tableName = $tbl.Trim()
    if($tbl -match "(?'Schema'.+)\.(?'Table'.+)") {
        $schemaName = $Matches['Schema']
        $tableName = $Matches['Table']
    }

    $schemaName = $schemaName.Trim().Trim('[').Trim(']').Trim()
    $tableName = $tableName.Trim().Trim('[').Trim(']').Trim()

    $tableNamesWithoutSchema += $tableName
}

$tableNamesWithoutSchemaCSV = ($tableNamesWithoutSchema | ForEach-Object {"'$_'"}) -join ','
$sqlCheckIdentity = $sqlCheckIdentity.Replace("<<table_names_without_schemas>>", "$tableNamesWithoutSchemaCSV")

# collection to store result
[System.Collections.ArrayList]$IdentityResult = @()

# Fetch Identity Check for Publisher
$conPublisherServer = Connect-DbaInstance -SqlInstance $PublisherServer -Database $PublisherDatabase -SqlCredential $SqlCredential -ClientName "(dba) IdentityCheck" -TrustServerCertificate -EncryptConnection -ErrorAction Stop -Debug:$false
$sqlCheckIdentity4Publisher = $sqlCheckIdentity
$sqlCheckIdentity4Publisher = $sqlCheckIdentity4Publisher.Replace("<server_name>", "$PublisherServer")
#$resultIdentityCheckPublisher = @()
#$resultIdentityCheckPublisher += 
$conPublisherServer | Invoke-DbaQuery -Query $sqlCheckIdentity4Publisher -EnableException | ForEach-Object {$IdentityResult.Add($_)|Out-Null}

# Fetch Identity Check for Subscriber
$conSubscriberServer = Connect-DbaInstance -SqlInstance $SubscriberServer -Database $SubsciberDatabase -SqlCredential $SqlCredential -ClientName "(dba) IdentityCheck" -TrustServerCertificate -EncryptConnection -ErrorAction Stop -Debug:$false
$sqlCheckIdentity4Subscriber = $sqlCheckIdentity
$sqlCheckIdentity4Subscriber = $sqlCheckIdentity4Subscriber.Replace("<server_name>", "$SubscriberServer")
$conSubscriberServer | Invoke-DbaQuery -Query $sqlCheckIdentity4Subscriber -EnableException | ForEach-Object {$IdentityResult.Add($_)|Out-Null}


#$IdentityResult | ogv

$tables4ReseedNeeded = @()
$tables4ReseedNeeded += $IdentityResult | Where-Object {$_.is_reseed_needed}

#Write-Debug "Debug here"

if ($tables4ReseedNeeded.Count -gt 0) 
{
    foreach($srv_db_row in $($tables4ReseedNeeded | Select-Object -Property server_name, database_name -Unique)) 
    {
        $server_name = $srv_db_row.server_name
        $database_name = $srv_db_row.database_name

        @"
/* ************************************************************************************************************
** ********** Reseed Identity for tables on [$server_name].[$database_name] *************
** ********************************************************************************************************** */

use [$database_name];

"@ | Out-File -Append $OutputFile

        foreach($table_row in $($tables4ReseedNeeded | Where-Object {$_.server_name -eq $server_name -and $_.database_name -eq $database_name})) 
        {        
            $table_name = $table_row.table_name
            $tsql_query = $table_row.tsql_to_reseed_identity

            @"
-- reseed table [$database_name].[$table_name]
$tsql_query

"@ | Out-File -Append $OutputFile
        }
    }
}
else {
    "`n-- No identity reseed needed`n`n" | Out-File -Append $OutputFile
}


# Show output
if($verbose) {
    "$(Get-Date -Format yyyyMMMdd_HHmm) {0,-10} {1}" -f 'INFO:', "open file '$OutputFile' in notepad.."
}
notepad $OutputFile


<#
cls
#$ReplCredential = Get-Credential -UserName 'sa' -Message 'REPL'

E:\Github\SQLMonitor\Work-TOM-GM-DR-Replication\9__replication_setup.ps1 `
        -DistributorServer 'SQLMonitor' `
        -PublisherServer 'Demo\SQL2019' `
        -PublisherDatabase 'DBA' `
        -SubscriberServer 'Experiment,1432' `
        -SubsciberDatabase 'DBATools' `
        -DataCenter NTT `
        -SqlCredential $ReplCredential `
        -Table @('dbo.file_io_stats','dbo.wait_stats','dbo.xevent_metrics','dbo.xevent_metrics_queries','dbo.sql_agent_job_stats') `
        -ReplLoginName $ReplCredential.UserName `
        -ReplLoginPassword $ReplCredential.GetNetworkCredential().Password `
        -LoginsForReplAccess @('grafana') `
        -IncludeAddDistributorScripts $false `
        -IncludeDropPublicationScripts $true `
        -Verbose -Debug

E:\Github\SQLMonitor\Work-TOM-GM-DR-Replication\9__replication_setup.ps1 `
        -DistributorServer 'SQLMonitor' `
        -PublisherServer 'Experiment,1432' `
        -PublisherDatabase 'DBATools' `
        -SubscriberServer 'Demo\SQL2019' `
        -DataCenter GPX `
        -SubsciberDatabase 'DBA' `
        -SqlCredential $ReplCredential `
        -Table @('dbo.file_io_stats','dbo.wait_stats','dbo.xevent_metrics','dbo.xevent_metrics_queries','dbo.sql_agent_job_stats') `
        -ReplLoginName $ReplCredential.UserName `
        -ReplLoginPassword $ReplCredential.GetNetworkCredential().Password `
        -LoginsForReplAccess @('grafana') `
        -IncludeAddDistributorScripts $false `
        -IncludeDropPublicationScripts $true `
        -Verbose -Debug


#>