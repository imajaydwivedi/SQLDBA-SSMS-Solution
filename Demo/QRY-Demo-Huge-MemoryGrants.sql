/*
Fundamentals of Parameter Sniffing
What Triggers Parameter Sniffing Emergencies, Part 2

v1.2 - 2020-08-04

https://www.BrentOzar.com/go/snifffund


This demo requires:
* SQL Server 2016 or newer
* 50GB Stack Overflow 2013 database: https://www.BrentOzar.com/go/querystack

This first RAISERROR is just to make sure you don't accidentally hit F5 and
run the entire script. You don't need to run this:
*/
RAISERROR(N'Oops! No, don''t just hit F5. Run these demos one at a time.', 20, 1) WITH LOG;
GO


/* Continue this demo after running the prior module.
  We're reusing the same setups from there.

These 3 are specialized: let's demo the first two and talk about the 3rd.

* Plan cache pressure due to unparameterized queries
* Memory pressure
* Plans aging out
*/

use StackOverflow2013
go

EXEC dbo.usp_UsersByReputation @Reputation =1;
GO
EXEC dbo.usp_UsersByReputation @Reputation =2;
GO

DBCC FREEPROCCACHE
GO
EXEC dbo.usp_UsersByReputation @Reputation =2;
GO
EXEC dbo.usp_UsersByReputation @Reputation =1;
GO
sp_BlitzCache
GO


/* How much plan cache history do we have? Originally published here:
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
ORDER BY 1 DESC, 2 DESC;
GO

/* Similarly: */
sp_BlitzCache;
GO
sp_Blitz;
GO
sp_BlitzFirst;
GO



CREATE OR ALTER PROC dbo.usp_GetUser @UserId INT = NULL, @DisplayName NVARCHAR(40) = NULL, @Location NVARCHAR(100) = NULL AS
BEGIN
/* They have to ask for either a UserId or a DisplayName or a Location: */
IF @UserId IS NULL AND @DisplayName IS NULL AND @Location IS NULL
	RETURN;

DECLARE @StringToExecute NVARCHAR(4000);
SET @StringToExecute = N'SELECT * FROM dbo.Users WHERE 1 = 1 ';

IF @UserId IS NOT NULL
	SET @StringToExecute = @StringToExecute + N' AND Id = ' + CAST(@UserId AS NVARCHAR(10));

IF @DisplayName IS NOT NULL
	SET @StringToExecute = @StringToExecute + N' AND DisplayName = ''' + @DisplayName + N'''';

IF @Location IS NOT NULL
	SET @StringToExecute = @StringToExecute + N' AND Location = ''' + @Location + N'''';

EXEC sp_executesql @StringToExecute;
END
GO


CREATE OR ALTER PROC [dbo].[usp_DynamicSQLLab] WITH RECOMPILE AS
BEGIN
	/* Hi! You can ignore this stored procedure.
	   This is used to run different random stored procs as part of your class.
	   Don't change this in order to "tune" things.
	*/
	SET NOCOUNT ON
 
	DECLARE @Id1 INT = CAST(RAND() * 1000000 AS INT) + 1,
			@Param1 NVARCHAR(100);

	IF @Id1 % 4 = 3
		EXEC dbo.usp_GetUser @UserId = @Id1;
	ELSE IF @Id1 % 4 = 2
		BEGIN
		SELECT @Param1 = Location FROM dbo.Users WHERE Id = @Id1 OPTION (RECOMPILE);
		EXEC dbo.usp_GetUser @Location = @Param1;
		END
	ELSE
		BEGIN
		SELECT @Param1 = DisplayName FROM dbo.Users WHERE Id = @Id1 OPTION (RECOMPILE);
		EXEC dbo.usp_GetUser @DisplayName = @Param1;
		END
END
GO

DBCC FREEPROCCACHE;
GO
EXEC [usp_DynamicSQLLab]
GO 500



/* Finding the culprits: */
sp_BlitzCache @SortOrder = 'recent compilations'
GO
sp_BlitzCache @SortOrder = 'query hash'
GO

/* Or this: Originally published here: 
https://www.brentozar.com/archive/2018/03/why-multiple-plans-for-one-query-are-bad/
*/
WITH RedundantQueries AS 
        (SELECT TOP 10 query_hash, statement_start_offset, statement_end_offset,
            /* PICK YOUR SORT ORDER HERE BELOW: */

            COUNT(query_hash) AS sort_order,            --queries with the most plans in cache

            /* Your options are:
            COUNT(query_hash) AS sort_order,            --queries with the most plans in cache
            SUM(total_logical_reads) AS sort_order,     --queries reading data
            SUM(total_worker_time) AS sort_order,       --queries burning up CPU
            SUM(total_elapsed_time) AS sort_order,      --queries taking forever to run
            */

            COUNT(query_hash) AS PlansCached,
            COUNT(DISTINCT(query_hash)) AS DistinctPlansCached,
            MIN(creation_time) AS FirstPlanCreationTime,
            MAX(creation_time) AS LastPlanCreationTime,
			MAX(s.last_execution_time) AS LastExecutionTime,
            SUM(total_worker_time) AS Total_CPU_ms,
            SUM(total_elapsed_time) AS Total_Duration_ms,
            SUM(total_logical_reads) AS Total_Reads,
            SUM(total_logical_writes) AS Total_Writes,
			SUM(execution_count) AS Total_Executions,
            --SUM(total_spills) AS Total_Spills,
            N'EXEC sp_BlitzCache @OnlyQueryHashes=''0x' + CONVERT(NVARCHAR(50), query_hash, 2) + '''' AS MoreInfo
            FROM sys.dm_exec_query_stats s
            GROUP BY query_hash, statement_start_offset, statement_end_offset
            ORDER BY 4 DESC)
SELECT r.query_hash, r.PlansCached, r.DistinctPlansCached, q.SampleQueryText, q.SampleQueryPlan, r.MoreInfo, 
        r.Total_CPU_ms, r.Total_Duration_ms, r.Total_Reads, r.Total_Writes, r.Total_Executions, --r.Total_Spills,
        r.FirstPlanCreationTime, r.LastPlanCreationTime, r.LastExecutionTime, r.statement_start_offset, r.statement_end_offset, r.sort_order
    FROM RedundantQueries r
    CROSS APPLY (SELECT TOP 10 st.text AS SampleQueryText, qp.query_plan AS SampleQueryPlan, qs.total_elapsed_time
        FROM sys.dm_exec_query_stats qs 
        CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
        CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
        WHERE r.query_hash = qs.query_hash
            AND r.statement_start_offset = qs.statement_start_offset
            AND r.statement_end_offset = qs.statement_end_offset
        ORDER BY qs.total_elapsed_time DESC) q
    ORDER BY r.sort_order DESC, r.query_hash, q.total_elapsed_time DESC;







/* Causing memory pressure from workspace grants */
DropIndexes;
GO
CREATE OR ALTER PROC dbo.usp_RptUsersLeaderboard AS
BEGIN
SELECT TOP 1000 *
	FROM dbo.Users
	ORDER BY Reputation DESC;
END
GO
/* Run that across several sessions at once */




/*
License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
More info: https://creativecommons.org/licenses/by-sa/4.0/

You are free to:
* Share - copy and redistribute the material in any medium or format
* Adapt - remix, transform, and build upon the material for any purpose, even 
  commercially

Under the following terms:
* Attribution - You must give appropriate credit, provide a link to the license, 
  and indicate if changes were made. You may do so in any reasonable manner, 
  but not in any way that suggests the licensor endorses you or your use.
* ShareAlike - If you remix, transform, or build upon the material, you must
  distribute your contributions under the same license as the original.
*/