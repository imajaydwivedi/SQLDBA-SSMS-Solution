-- Job [(dba) Collect Metrics - Purge Tables & Files]

-- Step 01 - Delete PerfMon Files
powershell.exe -ExecutionPolicy Bypass .  'D:\\MSSQL15.MSSQLSERVER\\MSSQL\Perfmon\perfmon-remove-imported-files.ps1';

-- Step 02 - Purge [dbo].[dm_os_memory_clerks]
set nocount on;
declare @retention_days int;
set @retention_days = 90;

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (10000) [dbo].[dm_os_memory_clerks] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end
go

-- Step 03 - Purge [dbo].[dm_os_performance_counters]
set nocount on;
declare @retention_days int;
set @retention_days = 90;

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (10000) [dbo].[dm_os_performance_counters] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end
go

-- Step 04 - Purge [dbo].[dm_os_performance_counters_nonsql]
set nocount on;
declare @retention_days int;
set @retention_days = 90;

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (10000) [dbo].[dm_os_performance_counters_nonsql] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end
go

-- Step 05 - Purge [dbo].[dm_os_process_memory]
set nocount on;
declare @retention_days int;
set @retention_days = 90;

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (10000) [dbo].[dm_os_process_memory] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end
go

-- Step 06 - Purge [dbo].[dm_os_ring_buffers]
set nocount on;
declare @retention_days int;
set @retention_days = 90;

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (10000) [dbo].[dm_os_ring_buffers] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end
go

-- Step 07 - Purge [dbo].[dm_os_sys_info]
set nocount on;
declare @retention_days int;
set @retention_days = 90;

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (10000) [dbo].[dm_os_sys_info] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end
go

-- Step 08 - Purge [dbo].[dm_os_sys_memory]
set nocount on;
declare @retention_days int;
set @retention_days = 90;

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (10000) [dbo].[dm_os_sys_memory] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end
go

-- Step 9 - Purge [dbo].[WaitStats]
set nocount on;
declare @retention_days int;
set @retention_days = 90;

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (10000) [dbo].[WaitStats] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end
go

-- Step 10 - Purge [dbo].[WhoIsActive_ResultSets]
set nocount on;
declare @retention_days int;
set @retention_days = 90;

declare @r int;
set @r = 1;

while @r > 0
begin
	delete top (10000) [dbo].[WhoIsActive_ResultSets] where collection_time < DATEADD(day,-@retention_days,GETDATE());

	set @r = @@ROWCOUNT;
end
go

