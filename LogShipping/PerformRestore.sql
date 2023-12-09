use master
go

--	Get all files of path
exec xp_dirtree '\\DC\Backups\SQL-A',0,1;

/*	Step 01 -> Restore Full & TLog in NORECOVERY */
/*	Step 02 -> Set the database in StandBy */
RESTORE DATABASE [LSTesting]
	WITH STANDBY = 'E:\LS_UndoFiles\LSTesting_undo.tuf'
GO

EXEC master..[usp_DBAApplyTLogs] 
		@p_SourceDbName = 'LSTesting'
		,@p_DestinationDbName = 'LSTesting'
		,@p_SourceBackupLocation = '\\DC\Backups\SQL-A\'
		,@p_TUFLocation = 'E:\LS_UndoFiles' 
		--,@p_Verbose = 1 
		--,@p_DryRun = 1