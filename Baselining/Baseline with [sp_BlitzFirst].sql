--	https://www.brentozar.com/askbrent/

-- Collect Data using below code
EXEC master..sp_BlitzFirst 
	@OutputDatabaseName = 'DBA',
	@OutputSchemaName = 'dbo',
	@OutputTableName = 'BlitzFirst', -- the quick diagnosis result set goes here
	@OutputTableNameFileStats = 'BlitzFirst_FileStats',
	@OutputTableNamePerfmonStats = 'BlitzFirst_PerfmonStats',
	@OutputTableNameWaitStats = 'BlitzFirst_WaitStats',
	@OutputTableNameBlitzCache = 'BlitzCache',
	@OutputTableNameBlitzWho = 'BlitzWho',
	@OutputTableRetentionDays = 90;

EXEC master..sp_BlitzFirst @Help = 1

-- Fetch stats As of Date
	-- sp_BlitzFirst will look in the output table for all results within 15 minutes of that time, and return them in chronological order. 
EXEC sp_BlitzFirst @AsOf = '2015-02-23 18:45', @OutputDatabaseName = 'DBAtools', @OutputSchemaName = 'dbo', @OutputTableName = 'BlitzFirstResults'

--	Customized
EXEC sp_BlitzFirst @AsOf = '2019-02-20 03:00', @OutputDatabaseName = 'DBA', @OutputSchemaName = 'dbo', @OutputTableName = 'BlitzFirst', @OutputTableNameFileStats = 'BlitzFirst_FileStats',  @OutputTableNamePerfmonStats = 'BlitzFirst_PerfmonStats',  @OutputTableNameWaitStats = 'BlitzFirst_WaitStats',  @OutputTableNameBlitzCache = 'BlitzCache'


