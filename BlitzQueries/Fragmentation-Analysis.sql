# Script to Get Fragmentation Stats for All Dbs on Multiple Servers (in Parallel Jobs)
$dbServers = @('DbServer01','DbServer02','DbServer03');

$dbQuery = @"
select d.name 
from sys.databases as d 
where not(d.source_database_id IS NOT NULL or d.state_desc = 'OFFLINE' or d.database_id <= 4)
and d.compatibility_level = (select m.compatibility_level from sys.databases as m where m.name = 'model')
"@;

$IndexQuery = @"
select	@@serverName as ServerName,
		db_name(ips.database_id) as DataBaseName,
		sch.name + '.' + object_name(ips.object_id) as TableName,
		ind.name as IndexName,
		ips.index_type_desc,
		ips.alloc_unit_type_desc,
		ODefrag.UpdatedTime as OlaIndexDefrag,
		avg_fragmentation_in_percent as avg_fragmentation,
		avg_page_space_used_in_percent,
		page_count,
		ps.row_count		
		--,sts.name as StatsName
		,sp.last_updated as stats_last_updated
		,sp.rows as stats_rows
		,sp.modification_counter as stats_modification_counter
		,STATS_DATE(ind.object_id, ind.index_id) AS StatsUpdated
		,OSts.UpdatedTime AS OlaStatsUpdated
		,[DeFrag_Filter = {PageCount >= 1000}] = case when ips.page_count >= 100 then 'Yes' else 'No' end
		,[Stats_Filter = {ModifiedStatistics}] = case when sp.modification_counter > 0 then 'Yes' else 'No' end
		,[Stats_Filter = {@StatisticsModificationLevel}] = case when SQRT(ps.row_count * 1000) >= sp.modification_counter then 'Yes' else 'No' end
from sys.dm_db_index_physical_stats(DB_ID(),NULL,NULL,NULL,'LIMITED') as ips
inner join sys.indexes as ind on ips.index_id = ind.index_id and ips.object_id = ind.object_id
inner join sys.tables as tbl on ips.object_id = tbl.object_id
inner join sys.schemas as sch on tbl.schema_id = sch.schema_id
inner join sys.dm_db_partition_stats as ps on ps.object_id = ips.object_id and ps.index_id = ips.index_id
left join sys.stats as sts on sts.object_id = ind.object_id
cross apply sys.dm_db_stats_properties(ind.object_id, sts.stats_id) as sp
outer apply (SELECT MAX(cl.EndTime) as UpdatedTime FROM DBA..CommandLog as cl WHERE cl.DatabaseName = DB_NAME() and tbl.name = cl.ObjectName and sch.name = cl.SchemaName and ind.name = cl.IndexName AND cl.CommandType = 'UPDATE_STATISTICS') AS OSts
outer apply (SELECT MAX(cl.EndTime) as UpdatedTime FROM DBA..CommandLog as cl WHERE cl.DatabaseName = DB_NAME() and tbl.name = cl.ObjectName and sch.name = cl.SchemaName and ind.name = cl.IndexName AND cl.CommandType = 'ALTER_INDEX') AS ODefrag
where sts.name = ind.name
order by avg_fragmentation DESC
"@;

foreach($srv in $dbServers) {
    Write-Host $srv -ForegroundColor DarkYellow;

    # find databases from server
    $alldbs = Invoke-DbaQuery -SqlInstance $srv -Query $dbQuery | Select-Object -ExpandProperty name;
    
    foreach($db in $alldbs) {
        Write-Host "`tJob started for [$srv].[$db]..." -ForegroundColor Green;
        $ScriptBlock = { 
            param($srv, $db, $IndexQuery)
            Invoke-DbaQuery -SqlInstance $srv -Database $db -Query $IndexQuery -QueryTimeOut 3600
        }
        Start-Job -Name "IndexStats-$srv-$db" -ScriptBlock $ScriptBlock -ArgumentList $srv, $db, $IndexQuery;
    }
} # Server loop
Write-Host "Jobs created/started for each Server/Database pair." -ForegroundColor Green;


$IndexAnalysisResult = @();
do {
    # Find completed jobs, Retrieve Data, and Remove them
    $Jobs_Completed = Get-Job -Name IndexStats* | Where-Object {$_.State -eq 'Completed'};
    $IndexAnalysisResult += $Jobs_Completed | Receive-Job;
    $Jobs_Completed | Remove-Job;

    # Wait for 10 seconds
    Start-Sleep -Seconds 10;
    $Jobs_Yet2Process = Get-Job -Name IndexStats* | 
                        Where-Object {$_.State -in ('NotStarted','Running','Suspending','Stopping')};
}
while($Jobs_Yet2Process -ne $null); # keep looping if jobs are still in progress

# Save to Excel
$IndexAnalysisResult | Export-Excel -Path C:\Temp\IndexAnalysisResult.xlsx -WorksheetName 'IndexAnalysisResult';


# Find Jobs with Failures
$Jobs_Issue = Get-Job -Name IndexStats* | 
              Where-Object {$_.State -notin ('Completed','NotStarted','Running','Suspending','Stopping')};
if($Jobs_Issue -ne $null) {
    Write-Host @"
Some jobs failed. Execute below script
`$Jobs_Yet2Process
"@
}

<#
$excel = Import-Excel 'C:\temp\IndexAnalysisResult.xlsx'
$i = 1
$excel | select -Property ServerName, DatabaseName -Unique | ForEach-Object {
            $_ | Add-Member -NotePropertyName ID -NotePropertyValue $i -PassThru;
            $i += 1;
        } | ogv
#>