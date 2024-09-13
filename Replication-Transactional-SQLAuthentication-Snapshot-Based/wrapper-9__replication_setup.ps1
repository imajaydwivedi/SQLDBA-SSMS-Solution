cls
$ReplLoginPassword = Read-Host "Enter ReplLoginPassword"
E:\Github\SQLMonitor\Work-TOM-GM-DR-Replication\9__replication_setup.ps1 `
        -DistributorServer 'SQLMonitor' `
        -PublicationName "GPX_Exp__DBA_2_DBATools_SQLMonitor_Tbls" `
        -PublisherServer 'Experiment,1432' `
        -SubscriberServer 'Demo\SQL2019' `
        -PublisherDatabase 'DBA' `
        -SubsciberDatabase 'DBATools' `
        -Table @('dbo.file_io_stats','[dbo].[wait_stats]','dbo.xevent_metrics',' xevent_metrics_queries','sql_agent_job_stats') `
        -ReplLoginName 'sa' -ReplLoginPassword $ReplLoginPassword `
        -LoginsForReplAccess @('sa','grafana') `
        -IncludeAddDistributorScripts $true `
        -IncludeDropPublicationScripts $true `
        -Verbose -Debug

cls
$ReplLoginPassword = Read-Host "Enter ReplLoginPassword"
E:\Github\SQLMonitor\Work-TOM-GM-DR-Replication\9__replication_setup.ps1 `
        -DistributorServer 'SQLMonitor' `
        -PublicationName "NTT_Demo__DBA_2_DBATools_SQLMonitor_Tbls" `
        -PublisherServer 'Demo\SQL2019' `
        -SubscriberServer 'Experiment,1432' `
        -PublisherDatabase 'DBA' `
        -SubsciberDatabase 'DBATools' `
        -Table @('dbo.file_io_stats','[dbo].[wait_stats]','dbo.xevent_metrics',' xevent_metrics_queries','sql_agent_job_stats') `
        -ReplLoginName 'sa' -ReplLoginPassword $ReplLoginPassword `
        -LoginsForReplAccess @('sa','grafana') `
        -IncludeAddDistributorScripts $false `
        -IncludeDropPublicationScripts $true `
        -Verbose -Debug

