To migrate the SSRS from 2008 to SSRS 2014, you can following steps below to use the RS.exe script to copies content items and settings from one SQL Server Reporting Services report server to another report server(for example reports and subscriptions,security setting from server to another server. The script supports both SharePoint mode and Native mode report servers):

1. using the RS.exe utility Download the script file from the CodePlex site Reporting Services RS.exe script migrates content to a local folder, for example c:\rss\ssrs_migration.rss.

2. Open a command prompt with administrative privileges.

3. Navigate to the folder containing the ssrs_migration.rss file.

4. Run the following command to migrate contents from the native mode Sourceserver to the native mode Targetserver:

rs.exe -i ssrs_migration.rss -e Mgmt2010 -s http://SourceServer/ReportServer -u Domain\User -p password -v ts="http://TargetServer/reportserver" -v tu="Domain\Userser" -v tp="password"

More Details information:
Sample Reporting Services rs.exe Script to Migrate Content between Report Servers

Please reference to details steps about the migration and upgrade in these article:
Migrate a Reporting Services Installation (Native Mode) - google
Upgrade and Migrate Reporting Services - google
Migrating SQL Reporting Services to a new server by moving the Reporting Services databases - google

After you restored the related DB from the old 2008 to the new 2014, when you create an new project on the 2014 and import the rdl reports from the 2008 into this project, you just need to change the connection string to make the report works fine.