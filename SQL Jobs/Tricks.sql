1) Log To file - Dynamic options
-- https://docs.microsoft.com/en-us/sql/ssms/agent/use-tokens-in-job-steps?view=sql-server-ver15
F:\MSSQL15.MSSQLSERVER\Backup\JobLogs\DatabaseBackup_FULL_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt

J:\MSSQL15.MSSQLSERVER\Logs\DBA - Replication Distribution Agent Check_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt

2) Reporting and alerting on job failure in SQL Server
https://www.sqlshack.com/reporting-and-alerting-on-job-failure-in-sql-server/

