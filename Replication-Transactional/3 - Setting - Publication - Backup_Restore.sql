/* 
1. Create publication and articles
2. Take backup on Publ.
3. Restore backup on Subr. Don't forget to recover the DB. It cannot be left in no_recovery.
4. Point subr to backup file and create subr.
5. Done. Test to make sure the flow is working.
*/

USE [DBA];
GO

exec sp_helppublication @publication = 'DBA_Arc'  

EXEC sp_replicationdboption @dbname = N'DBA', 
	-- Can be "subscribe", "publish", "merge publish"
	-- and "sync with backup"
    @optname = N'publish', -- any type of publication
    @value = N'true';

-- ** Validate the new Log Reader SQL Server Agent Job created after adding publication with below query **
EXEC sp_addpublication @publication = N'DBA_Arc',
	@description = N'Transactional publication for database ''DBA'' from Publisher ''MSI''.',
    @sync_method = N'concurrent',
	@retention = 0, 
	@allow_push = N'true', 
	@allow_pull = N'true',
    @snapshot_in_defaultfolder = N'true', 
	@compress_snapshot = N'false',
    @repl_freq = N'continuous', 
	@status = N'active',
    @independent_agent = N'true', 
	-- We'll talk more about immediate sync
	-- Big overhead considerations!
    @immediate_sync = N'false', /* If true, the synchronization files are created or re-created each time the Snapshot Agent runs */
	@replicate_ddl = 1,
    @allow_initialize_from_backup = N'true', 
	@enabled_for_p2p = N'false',
    @enabled_for_het_sub = N'false';
GO

use [ContsoSQLInventory]
exec sp_addarticle @publication = N'DIMS', @article = N'Application', @source_owner = N'dbo', @source_object = N'Application', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'drop', @schema_option = 0x000000000803509F, @identityrangemanagementoption = N'manual', @destination_table = N'Application', @destination_owner = N'dbo', @status = 24, @vertical_partition = N'false', @ins_cmd = N'CALL [sp_MSins_dboApplication]', @del_cmd = N'CALL [sp_MSdel_dboApplication]', @upd_cmd = N'SCALL [sp_MSupd_dboApplication]'
GO
use [ContsoSQLInventory]
exec sp_addarticle @publication = N'DIMS', @article = N'auth_group', @source_owner = N'dbo', @source_object = N'auth_group', @type = N'logbased', @description = N'', @creation_script = N'', @pre_creation_cmd = N'drop', @schema_option = 0x000000000803509F, @identityrangemanagementoption = N'manual', @destination_table = N'auth_group', @destination_owner = N'dbo', @status = 24, @vertical_partition = N'false', @ins_cmd = N'CALL [sp_MSins_dboauth_group]', @del_cmd = N'CALL [sp_MSdel_dboauth_group]', @upd_cmd = N'SCALL [sp_MSupd_dboauth_group]'
GO

/*
EXEC [ContsoSQLInventory].sys.sp_addlogreader_agent @job_login = N'SQLSKILLSDEMOS\Administrator',
    @job_password = 'Password;1', @publisher_security_mode = 1
 -- Windows Auth
GO

-- Create the snapshot agent
EXEC sp_addpublication_snapshot @publication = N'Pub_Credit',
	-- Daily 
    @frequency_type = 4, @frequency_interval = 1,
    @frequency_relative_interval = 1, @frequency_recurrence_factor = 0,
    @frequency_subday = 8, @frequency_subday_interval = 1,
    @active_start_time_of_day = 0, @active_end_time_of_day = 235959,
    @active_start_date = 0, @active_end_date = 0,
    @job_login = N'SQLSKILLSDEMOS\Administrator', @job_password = 'Password;1',
    @publisher_security_mode = 1;
GO
*/

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