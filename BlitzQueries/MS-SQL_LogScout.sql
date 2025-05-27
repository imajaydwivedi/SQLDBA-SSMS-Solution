/*
https://github.com/microsoft/SQL_LogScout
SQL LogScout allows you to collect diagnostic logs from your SQL Server system to help you and 
Microsoft technical support engineers (CSS) to resolve SQL Server technical incidents faster. 
It is a light, script-based, open-source tool that is version-agnostic.

This tool is similar to DiagManager, PssDiag & SqlDiag.

The result can be consumed by SQL Nexus.

# Automate data collection
https://github.com/microsoft/SQL_LogScout?tab=readme-ov-file#automate-data-collection

SQL LogScout can be executed with multiple parameters allowing for full automation and no interaction with menus. You can:

Provide the SQL Server instance name
Select which scenario(s) to collect data for
Schedule start and stop time of data collection
Use Quiet mode to accept all prompts automatically
Choose the destination output folder (custom location, delete default or create a new one folder)
Use the RepeatCollections (continuous mode) option to run SQL LogScout multiple times

## Execute SQL LogScout with multiple scenarios and in Quiet mode
	# https://github.com/microsoft/SQL_LogScout?tab=readme-ov-file#f-execute-sql-logscout-with-multiple-scenarios-and-in-quiet-mode
SQL_LogScout.ps1 -Scenario "GeneralPerf+AlwaysOn+BackupRestore" -ServerName "DbSrv" -CustomOutputPath "d:\log" -DeleteExistingOrCreateNew "DeleteDefaultFolder" -DiagStartTime "01-01-2000" -DiagStopTime "04-01-2021 17:00" -InteractivePrompts "Quiet"
*/

