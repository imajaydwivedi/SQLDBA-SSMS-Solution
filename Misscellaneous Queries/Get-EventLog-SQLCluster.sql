#Get-EventLog -List
$Begin = Get-Date -Date '9/21/2019 07:00:00'
$End = Get-Date -Date '9/21/2019 08:30:00'

$a = Get-EventLog -ComputerName ClusterNode01,ClusterNode02 -LogName System -After $Begin -Before $End | Where-Object {$_.Message -like '*SQL*'}
$a | Select-Object * | ogv

$a | Sort-Object -Property TimeGenerated | Export-Clixml -Path c:\EventLogs_ACE_Cluster.xml

$logs = Import-Clixml 'C:\Users\adwivedi\OneDrive - contso Inc\Attachments\Daily Tasks\2019 Sep\EventLogs_ACE_Cluster.xml'
$logs | Where-Object {$_.Source -ne 'DCOM'} | select TimeGenerated, MachineName, EventID, EntryType, Source, Message | ogv
