use DBA
go

EXECUTE dbo.DatabaseBackup
			@Databases = '[Tesla]',
			--@Databases = '[Facebook],[Twitter],[Test_db],[Testdb]',
			@Directory = '\\SomePathHere\D$\ServerNameHere\',
			@DirectoryStructure = '{DatabaseName}',
			@BackupType = 'FULL',
			--@NumberOfFiles = 2,
			@CopyOnly = 'Y',
			@Init = 'Y',
			@Verify = 'Y',
			@Compress = 'Y',
			@CheckSum = 'Y',
			--@CleanupTime = 24,
			@Execute = 'Y'
go


--exec xp_dirtree '\\192.168.100