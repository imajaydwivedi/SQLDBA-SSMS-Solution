--	https://www.scalesql.com/cleartrace/
--select @@servername, db_name()
USE DbServerName01_May02
GO

DECLARE @serverName nvarchar(255)
SET @serverName = 'DbServerName01';

--	SELECT [TraceID], [TraceName] FROM [dbo].[CTTrace];

/*	 Update ServerName for Distributed Queries */
/*
UPDATE [dbo].[CTServer]
SET [ServerName] = @serverName
WHERE LEN([ServerName]) = 0
*/

/*	02) Main Query showing Agreegated Data */
;WITH tSummary AS
(
	SELECT	srv.ServerName, cast(dd.CalendarDate as date) as CalendarDate, RowID, EventClass, 
			a.ApplicationName, l.LoginName, h.HostName, 
			CPU, Reads, Writes, Duration, ExecutionCount, 
			NormalizedTextData, SampleTextData
	  FROM [dbo].[CTTraceSummary] as s
	left join
			[dbo].[CTServer] as srv
		on srv.ServerID = s.ServerID
	left join
		[dbo].[CTTextData] as td
		on td.TextDataHashCode = s.TextDataHashCode
	left join
		[dbo].[CTDateDimension] as dd
		on dd.DateID = s.DateID
	left join
		[dbo].[CTLogin] as l
		on l.LoginID = s.LoginID
	left join
		[dbo].[CTHost] as h
		on h.HostID = s.HostID
	left join
		[dbo].[CTApplication] as a
		on a.ApplicationID = s.ApplicationID
	--WHERE srv.ServerName = @serverName	
	--WHERE TraceID IN (2) /* SELECT [TraceID], [TraceName] FROM [dbo].[CTTrace]; */
)
,tAggregated AS 
(
	SELECT	ServerName, CalendarDate
			,[Item] = NormalizedTextData
			,[ExecutionCounts] = SUM(ExecutionCount)
			,[CPU] = SUM(CPU)
			,[Reads] = SUM(Reads)
			,[Writes] = SUM(Writes)
			,[Duration] = SUM(Duration)
			,[Reads_Max] = MAX(Reads)
			,[Reads_Min] = MIN(Reads)
			,[Writes_Max] = MAX(Writes)
			,[Writes_Min] = MIN(Writes)
	FROM	tSummary
	GROUP BY ServerName, CalendarDate, NormalizedTextData
)
SELECT	TOP (15) ServerName, CalendarDate, Item as SqlCode, ExecutionCounts, CPU, Reads, AverageReads = Reads/ExecutionCounts, Writes, Duration
		/*
		,[SampleText01] = (
				SELECT	TOP 1 t.SampleTextData
				FROM	[dbo].[CTTextData] AS t
				INNER JOIN
						[dbo].[CTTraceSummary] AS s
					ON	s.[TextDataHashCode] = t.[TextDataHashCode]
				WHERE	t.NormalizedTextData = a.Item
					AND	s.Reads = a.Reads_Max
			)
		,[SampleText02] = (
				SELECT	TOP 1 t.SampleTextData
				FROM	[dbo].[CTTextData] AS t
				INNER JOIN
						[dbo].[CTTraceSummary] AS s
					ON	s.[TextDataHashCode] = t.[TextDataHashCode]
				WHERE	t.NormalizedTextData = a.Item
					AND	s.Reads = a.Reads_Min
			)
		*/
FROM	tAggregated AS a
--ORDER BY (Reads+[Writes]) DESC
ORDER BY [Duration] DESC


/*	01) Base Query	*/
/*
SELECT	cast(dd.CalendarDate as date) as CalendarDate, RowID, EventClass, 
		a.ApplicationName, l.LoginName, h.HostName, 
		CPU, Reads, Writes, Duration, ExecutionCount, 
		NormalizedTextData, SampleTextData
  FROM [dbo].[CTTraceSummary] as s
left join
	[dbo].[CTTextData] as td
	on td.TextDataHashCode = s.TextDataHashCode
left join
	[dbo].[CTDateDimension] as dd
	on dd.DateID = s.DateID
left join
	[dbo].[CTLogin] as l
	on l.LoginID = s.LoginID
left join
	[dbo].[CTHost] as h
	on h.HostID = s.HostID
left join
	[dbo].[CTApplication] as a
	on a.ApplicationID = s.ApplicationID
--where td.NormalizedTextData = 'EXEC [DBO].[usp_get_user_votes] @URLSOURCE={STR}'
ORDER BY [Reads] DESC;
*/