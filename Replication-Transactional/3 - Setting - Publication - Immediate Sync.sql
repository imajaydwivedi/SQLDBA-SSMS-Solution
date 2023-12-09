USE DBA;
GO

EXEC sp_replicationdboption @dbname = N'DBA', 
	-- Can be "subscribe", "publish", "merge publish"
	-- and "sync with backup"
    @optname = N'publish', -- any type of publication
    @value = N'true';

EXEC [Credit].sys.sp_addlogreader_agent @job_login = N'SQLSKILLSDEMOS\Administrator',
    @job_password = 'Password;1', @publisher_security_mode = 1
 -- Windows Auth
GO

-- ** Validate the new Log Reader SQL Server Agent Job **

EXEC sp_addpublication @publication = N'DBAReplSyncOnly',
    @sync_method = N'concurrent', @allow_push = N'true', @allow_pull = N'true',
    @snapshot_in_defaultfolder = N'true', @compress_snapshot = N'false',
    @repl_freq = N'continuous', @status = N'active',
    @independent_agent = N'true', 
	-- We'll talk more about immediate sync
	-- Big overhead considerations!
    @immediate_sync = N'false', @replicate_ddl = 1,
    @allow_initialize_from_backup = N'false', @enabled_for_p2p = N'false',
    @enabled_for_het_sub = N'false';
GO

-- Create the snapshot agent
EXEC sp_addpublication_snapshot @publication = N'DBAReplSyncOnly'
	-- Daily 
    --,@frequency_type = 4, @frequency_interval = 1,
    --@frequency_relative_interval = 1, @frequency_recurrence_factor = 0,
    --@frequency_subday = 8, @frequency_subday_interval = 1,
    --@active_start_time_of_day = 0, @active_end_time_of_day = 235959,
    --@active_start_date = 0, @active_end_date = 0,
    --@job_login = N'SQLSKILLSDEMOS\Administrator', @job_password = 'Password;1',
    --@publisher_security_mode = 1;
GO

-- Table - HumanResources.Department
EXEC sp_addarticle @publication = N'Pub_Credit', @article = N'category',
    @source_owner = N'dbo', @source_object = N'category', 
	-- What to do if object exists at subscriber
	-- Other options are "none", "delete", "truncate"
    @pre_creation_cmd = N'drop', 
	-- Bitmask for the assorted schema gen options
	-- (Check out the analysis script to see options)
    @schema_option = 0x00000000080350DF, 
	-- Manual = NOT FOR REPLICATION (we'll discuss later)
    @identityrangemanagementoption = N'manual',
    @destination_table = N'category', @destination_owner = N'dbo', 
	-- Column filtering (sp_articlecolumn then used if true)
    @vertical_partition = N'false',
	-- Replication command for data modifications 
    @ins_cmd = N'CALL sp_MSins_dbocategory',
    @del_cmd = N'CALL sp_MSdel_dbocategory',
    @upd_cmd = N'SCALL sp_MSupd_dbocategory';
GO

/*
	0x00000000080350DF translates to...
	
0x01 - Generates the object creation script (CREATE TABLE, CREATE PROCEDURE, and so on). This value is the default for stored procedure articles.
0x02 - Generates the stored procedures that propagate changes for the article, if defined.
0x04 - Identity columns are scripted using the IDENTITY property.
0x08 - Replicate timestamp columns. If not set, timestamp columns are replicated as binary.
0x10 - Generates a corresponding clustered index. Even if this option is not set, indexes related to primary keys and unique constraints are generated if they are already defined on a published table.
0x40 - Generates corresponding nonclustered indexes. Even if this option is not set, indexes related to primary keys and unique constraints are generated if they are already defined on a published table.
0x80 - Replicates primary key constraints. Any indexes related to the constraint are also replicated, even if options 0x10 and 0x40 are not enabled.
0x1000 - Replicates column-level collation
0x4000 - Replicates UNIQUE constraints. Any indexes related to the constraint are also replicated, even if options 0x10 and 0x40 are not enabled
0x10000 - Replicates CHECK constraints as NOT FOR REPLICATION so that the constraints are not enforced during synchronization
0x20000 - Replicates FOREIGN KEY constraints as NOT FOR REPLICATION so that the constraints are not enforced during synchronization
0x8000000 - Creates any schemas not already present on the subscriber
*/