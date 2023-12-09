1) When writing alert, implement auto clear logic, delay parameter, and use global profile
2) When using SQL Agent jobs, use available tokens like job_id, job_name, step_name, server_name etc
3) Add verbose switch in tsql with 0 (no message),1(message),2 values (messages & table results)
4) Identify Caller using program_name()
	SSMS -> Microsoft SQL Server Management Studio - Query
	Agent -> SQLAgent - TSQL JobStep (Job 0x97544499D70588418EAEE4D198D90D37 : Step 1)
5) If Job history is required, then Jobs should log execution history in table dbo.sdt_job_execution_log