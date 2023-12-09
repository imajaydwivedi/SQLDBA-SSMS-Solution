select cast(el.TimeGenerated as smalldatetime) as TimeGenerated, 
		el.UserName, el.EventID, el.EntryType, el.Source
		,el.Message
from tempdb..event_logs_ajay as el
where ((Source = 'Microsoft-Windows-FailoverClustering')
	or (Source = 'Service Control Manager' and (Message like '%stop%' or Message like '%running%') )
	or (Source = 'Service Control Manager' and Message like '%SQL Server%')
	  )
	  and
	  (	 Message not like 'The Background Intelligent Transfer Service service%'
	  and Message not like 'The Remote Registry service%'
	  and Message not like 'The AppX Deployment Service (AppXSVC) service%'
	  and Message not like 'The Microsoft Monitoring Agent service%'
	  and Message not like 'The Microsoft Account Sign-in Assistant service%'
	  )
order by el.TimeGenerated

/*
$server = 'ServerNameHere'
$Begin = Get-Date -Date '8/16/2020 02:00:00'
$End = Get-Date -Date '8/16/2020 02:55:00'
$event_logs = Get-EventLog -LogName System -After $Begin -Before $End
$event_logs | Write-DbaDataTable -Database tempdb -SqlInstance $server -Table 'event_logs_ajay' -AutoCreateTable


$tql_query = @"
select cast(el.TimeGenerated as smalldatetime) as TimeGenerated, 
		el.UserName, el.EventID, el.EntryType, el.Source
		,el.Message
from tempdb..event_logs_ajay as el
where ((Source = 'Microsoft-Windows-FailoverClustering')
	or (Source = 'Service Control Manager' and (Message like '%stop%' or Message like '%running%') )
	or (Source = 'Service Control Manager' and Message like '%SQL Server%')
	  )
	  and
	  (	 Message not like 'The Background Intelligent Transfer Service service%'
	  and Message not like 'The Remote Registry service%'
	  and Message not like 'The AppX Deployment Service (AppXSVC) service%'
	  and Message not like 'The Microsoft Monitoring Agent service%'
	  and Message not like 'The Microsoft Account Sign-in Assistant service%'
	  )
order by el.TimeGenerated
"@;

$query_rs = Invoke-DbaQuery -SqlInstance $server -Query $tql_query
cls
$query_rs | Out-String
*/