EXEC tempdb..sp_BlitzCache @Help = 1
    -- @SortOrder = 'CPU', 
    -- Possible values are: "CPU", "Reads", "Writes", "Duration", "Executions", "Recent Compilations", "Memory Grant", "Unused Grant", "Spills", "Query Hash", "Duplicate". 
    -- Additionally, the word "Average" or "Avg" can be used to sort on averages rather than total. "Executions per minute" and "Executions / minute" can be used to sort by execution per minute.
    -- For the truly lazy, "xpm" can also be used. Note that when you use all or all avg, the only parameters you can use are @Top and @DatabaseName. All others will be ignored.

-- ******************* Issue 01: Blocking *******************
exec master..sp_BlitzCache @SortOrder = 'Duration', @AI = 1;
/* Look for in the warning column: Long Running, Low CPU (this means the blocked queries) */

exec master..sp_BlitzIndex @GetAllDatabases = 1;
/* Look for "Aggresive Indexes" and read the warning URL */

-- Also, check if RCSI can be implemented - https://www.BrentOzar.com/go/rcsi


-- ******************* Issue 02: Non-Data Page IO Issues *******************
exec master..sp_BlitzCache @SortOrder = 'Duration', @AI = 1;
/* Look for in the warning column: Long Running, Low CPU (this means the blocked queries) */



EXEC tempdb..sp_BlitzCache @ExpertMode = 1, @ExportToExcel = 1

--	https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit#common-sp_blitzcache-parameters
EXEC master..sp_BlitzCache @Top = 30, @SortOrder = 'reads', @IgnoreSystemDBs = 0, -- queries doing lot of reads
					@OutputDatabaseName = 'DBA', @OutputSchemaName = 'dbo', @OutputTableName = 'BlitzCache'
EXEC master..sp_BlitzCache @Top = 30, @SortOrder = 'writes' -- queries with high writes
EXEC master..sp_BlitzCache @Top = 30, @SortOrder = 'memory grant' -- Queries using maximum memory grant
exec master..sp_BlitzCache @SortOrder = 'spills', @Top = 30 -- Queries spilling to disk
exec master..sp_BlitzCache @SortOrder = 'unused grant', @Top = 30 -- Queries asking for huge memory grant, but simply wasting it.

exec master..sp_BlitzCache @SortOrder = 'CPU', @Top = 30 -- Queries with High executions
					,@OutputDatabaseName = 'DBA', @OutputSchemaName = 'dbo', @OutputTableName = 'BlitzCache_CPU_20230321'
exec master..sp_BlitzCache @SortOrder = 'xpm', @Top = 30 -- Queries with High executions
					,@OutputDatabaseName = 'DBA', @OutputSchemaName = 'dbo', @OutputTableName = 'BlitzCache_xpm_20230321'
exec master..sp_BlitzCache @SortOrder = 'recent compilations', @Top = 2000, @SkipAnalysis = 1 -- Recently compiled queries that may need parametization
					,@OutputDatabaseName = 'DBA', @OutputSchemaName = 'dbo', @OutputTableName = 'BlitzCache_RecentCompilations_20230321'

select top 500 * from DBA.dbo.BlitzCache

--	Analyze using Procedure Name
exec master..sp_BlitzCache @StoredProcName = 'Usp_Get_User_Upvotes'

--	Analyze using Query Hash in case SQL Code is not procedure
exec tempdb..sp_BlitzCache @OnlyQueryHashes = '0x998533A642130191'


