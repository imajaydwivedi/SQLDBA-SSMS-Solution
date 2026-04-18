/*
  vss-tlog-job.sql
  ----------------
  Creates a SQL Agent job on AgHost-1A that takes transaction log backups
  every 15 minutes for all user databases in FULL recovery model.

  Databases covered : CDCDemo, Db2, DBA, Facebook
  Backup directory  : E:\TLogBackups\
  Filename format   : {db}_{YYYYMMDD_HHMMSS}.trn
  Schedule          : Every 15 minutes, all day
  Retention on disk : 48 hours (purge step runs after each backup)

  Run on            : AgHost-1A  (192.168.122.247)
*/
USE msdb;
GO

-- ── Safety: drop job if it already exists ──────────────────────────────────
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'VSS-TLog-Backup-15min')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = N'VSS-TLog-Backup-15min', @delete_unused_schedule = 1;
    PRINT 'Existing job dropped.';
END
GO

-- ── Create job ─────────────────────────────────────────────────────────────
EXEC msdb.dbo.sp_add_job
    @job_name        = N'VSS-TLog-Backup-15min',
    @enabled         = 1,
    @description     = N'Transaction log backups every 15 min for VSS warm-standby on SqlPoc.',
    @category_name   = N'[Uncategorized (Local)]',
    @owner_login_name= N'sa';
GO

-- ── Job step : single step runs T-SQL for all DBs ──────────────────────────
EXEC msdb.dbo.sp_add_jobstep
    @job_name    = N'VSS-TLog-Backup-15min',
    @step_name   = N'Backup T-logs for all VSS databases',
    @subsystem   = N'TSQL',
    @command     = N'
SET NOCOUNT ON;
DECLARE @db   SYSNAME;
DECLARE @path NVARCHAR(500);
DECLARE @sql  NVARCHAR(MAX);
DECLARE @ts   VARCHAR(20) = REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR,GETDATE(),120),'':'',''''),''-'',''''),'' '',''_'');

-- Ensure backup directory exists
BEGIN TRY
    EXEC xp_cmdshell ''IF NOT EXIST E:\TLogBackups\ MKDIR E:\TLogBackups\'', NO_OUTPUT;
END TRY BEGIN CATCH END CATCH;

DECLARE db_cur CURSOR FAST_FORWARD FOR
    SELECT name FROM sys.databases
    WHERE state_desc = ''ONLINE''
      AND recovery_model_desc = ''FULL''
      AND name NOT IN (''master'',''model'',''msdb'',''tempdb'',''StackOverflow2013'')
    ORDER BY name;

OPEN db_cur;
FETCH NEXT FROM db_cur INTO @db;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @path = N''E:\TLogBackups\'' + @db + N''_'' + @ts + N''.trn'';
    SET @sql  = N''BACKUP LOG ['' + @db + N''] TO DISK = N'''''' + @path
              + N'''''' WITH COMPRESSION, STATS = 10;'';
    BEGIN TRY
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        PRINT ''FAIL '' + @db + '': '' + ERROR_MESSAGE();
    END CATCH;
    FETCH NEXT FROM db_cur INTO @db;
END
CLOSE db_cur;
DEALLOCATE db_cur;
',
    @on_success_action = 3,   -- Go to next step (purge)
    @on_fail_action    = 3,   -- Go to next step even on failure so stale files still get purged
    @retry_attempts    = 0;
GO

-- ── Job step 2 : purge .trn files older than 48 hours ──────────────────────
EXEC msdb.dbo.sp_add_jobstep
    @job_name    = N'VSS-TLog-Backup-15min',
    @step_name   = N'Purge T-logs older than 48 hours',
    @subsystem   = N'TSQL',
    @command     = N'
SET NOCOUNT ON;
DECLARE @cutoff DATETIME = DATEADD(HOUR, -48, GETDATE());
BEGIN TRY
    EXEC master.dbo.xp_delete_file 0, N''E:\TLogBackups'', N''trn'', @cutoff, 0;
    PRINT ''Purged *.trn files older than '' + CONVERT(VARCHAR(25), @cutoff, 120);
END TRY
BEGIN CATCH
    PRINT ''Purge failed: '' + ERROR_MESSAGE();
END CATCH;
',
    @on_success_action = 1,   -- Quit with success
    @on_fail_action    = 2,   -- Quit with failure
    @retry_attempts    = 0;
GO

-- ── Schedule: every 15 minutes, start now ──────────────────────────────────
EXEC msdb.dbo.sp_add_schedule
    @schedule_name           = N'Every15Minutes',
    @freq_type               = 4,        -- Daily
    @freq_interval           = 1,
    @freq_subday_type        = 4,        -- Minutes
    @freq_subday_interval    = 15,
    @active_start_time       = 0;
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name      = N'VSS-TLog-Backup-15min',
    @schedule_name = N'Every15Minutes';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name   = N'VSS-TLog-Backup-15min',
    @server_name= N'(LOCAL)';
GO

PRINT 'Job VSS-TLog-Backup-15min created and enabled.';
GO

-- ── Run once immediately to seed the log chain ─────────────────────────────
EXEC msdb.dbo.sp_start_job @job_name = N'VSS-TLog-Backup-15min';
GO
PRINT 'First execution triggered.';
