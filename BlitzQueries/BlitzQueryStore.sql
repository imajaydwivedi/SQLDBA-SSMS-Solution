/* Get the top 10: */
EXEC sp_BlitzQueryStore @DatabaseName = 'StackOverflow', @Top = 10

/* Minimum execution count, duration filter (seconds) */
EXEC sp_BlitzQueryStore @DatabaseName = 'StackOverflow', 
@Top = 10, @MinimumExecutionCount = 10, @DurationFilter = 2

/* Look for a stored procedure by name, get its params quickly */
EXEC sp_BlitzQueryStore @DatabaseName = 'StackOverflow', 
	@Top = 10, @SkipXML = 1,
	@StoredProcName = 'usp_SearchPostsByLocation_Recompile_OUTside'

/* Filter for a date range: */
EXEC sp_BlitzQueryStore @DatabaseName = 'StackOverflow', 
@Top = 10, @StartDate = '20200530', @EndDate = '20200605'
GO


/* To find out if your server is going to have a problem with constant query
compilations triggering Query Store to do a lot of work, run this:
https://www.brentozar.com/archive/2018/07/tsql2sday-how-much-plan-cache-history-do-you-have/
*/
SELECT TOP 50
    creation_date = CAST(creation_time AS date),
    creation_hour = CASE
                        WHEN CAST(creation_time AS date) <> CAST(GETDATE() AS date) THEN 0
                        ELSE DATEPART(hh, creation_time)
                    END,
    SUM(1) AS plans
FROM sys.dm_exec_query_stats
GROUP BY CAST(creation_time AS date),
         CASE
             WHEN CAST(creation_time AS date) <> CAST(GETDATE() AS date) THEN 0
             ELSE DATEPART(hh, creation_time)
         END
ORDER BY 1 DESC, 2 DESC