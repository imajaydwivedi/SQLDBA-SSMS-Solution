--	https://social.msdn.microsoft.com/Forums/sqlserver/en-US/945cab5d-b8eb-4c15-93ff-b4ddbba1f7f2/creating-an-alert-for-blocked-process-threshold?forum=sqldatabaseengine
/*
1) Create a table BLOCKED_PROCESS_REPORT in MSDB daabase.
2) Create a WMI based ALERT to capture BLOCKED PROCESS based on THREASHOLD value (in this example its set to 20 seconds).
3) Create a SQL AGENT JOB which will execute once this ALERT got fired. This job will write information to a table and then send an email alert.
4) It will send an email which will provide BLOCKING GRAPH like below which you can monitor later on.
*/
exec sp_configure 'show advanced options', 1 ;  
GO  
RECONFIGURE ;  
GO  
exec sp_configure 'blocked process threshold', 1 ; -- 1 minutes  
GO  
RECONFIGURE ;  
GO