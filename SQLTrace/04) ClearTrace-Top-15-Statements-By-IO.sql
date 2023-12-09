/* Top 15 Statements Group by SQL Text Order by IO */
;WITH CTE AS (
	SELECT 
     TextDataHashCode, NormalizedTextData  AS Item,
	SUM(ExecutionCount) AS [#],
	SUM(CPU) AS CPU,
	CAST(CAST(SUM(CPU) AS DECIMAL(22,2))/ SUM(ExecutionCount) AS DECIMAL(22,2)) AS AvgCPU,
	SUM(Reads) AS Reads,
	CAST(CAST(SUM(Reads) AS DECIMAL(22,2))/ SUM(ExecutionCount) AS DECIMAL(22,2)) AS AvgReads,
	SUM(Writes) AS Writes,
	CAST(CAST(SUM(Writes) AS DECIMAL(22,2))/ SUM(ExecutionCount) AS DECIMAL(22,2)) AS AvgWrites,
	SUM(Duration) AS Duration,
	CAST(CAST(SUM(Duration) AS DECIMAL(22,2))/ SUM(ExecutionCount) AS DECIMAL(22,2)) AS AvgDuration
	,ROW_NUMBER() OVER (ORDER BY SUM(CPU) DESC ) AS CpuRank
	,ROW_NUMBER() OVER (ORDER BY SUM(Reads) DESC ) AS ReadsRank

FROM 
	[dbo].[CTTraceSummaryView] TD
WHERE
   EventClass IN (41, 45)
AND
	NormalizedTextData IS NOT NULL
AND
	NormalizedTextData <> ''

GROUP BY 
	 TextDataHashCode, NormalizedTextData )
SELECT  TOP (15) WITH TIES 
    [TextDataHashCode]
    ,   
    [Item]
    ,[#]
    ,[CPU]
    ,[AvgCPU]
    ,[Reads]
    ,[AvgReads]
    ,[Writes]
    ,[AvgWrites]
    ,[Duration]
    ,[AvgDuration]
FROM [CTE] 
ORDER BY ([Reads]+[Writes]) DESC, ([AvgReads]+[AvgWrites]) DESC