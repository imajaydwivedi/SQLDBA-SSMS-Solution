--	http://www.sqlservercentral.com/articles/Administration/customlogshipping/1201/

/*	Step 01 -> Perform Full Backup	*/
BACKUP DATABASE [LSTesting]
	TO DISK = '\\DC\Backups\SQL-A\LSTesting_FullBackup_01Apr2018.bak'
GO

BACKUP LOG [LSTesting]
	TO DISK = '\\DC\Backups\SQL-A\LSTesting_TLog_01Apr2018.trn'
GO

/*	Step 02 -> Restore Full & TLog in NORECOVERY */
RESTORE DATABASE [LSTesting]
	FROM DISK = '\\DC\Backups\SQL-A\LSTesting_FullBackup_01Apr2018.bak'
	WITH NORECOVERY, REPLACE
GO

RESTORE LOG [LSTesting]
	FROM DISK = N'\\DC\Backups\SQL-A\master_TLog_2Apr2018_1246AM.trn'
	--WITH NORECOVERY
GO

/*	Step 03 -> Restore Full & TLog in NORECOVERY */
RESTORE DATABASE [LSTesting]
	WITH STANDBY = 'E:\LS_UndoFiles\LSTesting_undo.tuf'
GO


--	Find Log Shipping Jobs
SELECT	*
FROM	msdb..sysjobs as j
WHERE	j.category_id = 6;

--	Get variety of messages related to Log Shipping
SELECT	*
FROM	msdb.sys.sysmessages as m
WHERE	m.description LIKE '%Shipping%'
	AND	m.msglangid = 1033

--	Look for text in SQL Server Error Log
EXEC sys.xp_readerrorlog 0,1,'The log shipping primary database',NULL