USE DBA
GO

-- select distinct CheckDate from dbo.BlitzFirst order by CheckDate DESC
DECLARE @p_CheckDate_StartDateTime datetimeoffset,
		@p_CheckDate_EndDateTime datetimeoffset,		
        @p_Collection_StartTime datetime,
		@p_Collection_EndTime datetime;

SET @p_CheckDate_StartDateTime = '2019-03-12 00:00:01.1477067 -05:00';
SET @p_CheckDate_EndDateTime = '2019-03-12 06:30:00.7263793 -05:00';

SET @p_Collection_StartTime = (SELECT MIN(collection_Time) AS collection_Time  FROM dbo.WhoIsActive_ResultSets WHERE collection_Time >= CAST(@p_CheckDate_StartDateTime AS DATETIME))
SET @p_Collection_EndTime = (SELECT MAX(collection_Time) AS collection_Time  FROM dbo.WhoIsActive_ResultSets WHERE collection_Time <= CAST(@p_CheckDate_EndDateTime AS DATETIME))

--SELECT * FROM DBA.dbo.BlitzFirst
--       WHERE CheckDate >= @p_CheckDate_StartDateTime
--			AND CheckDate <= @p_CheckDate_EndDateTime
--       ORDER BY CheckDate DESC, ID

SELECT collection_time as CheckDate, * FROM [DBA].[dbo].WhoIsActive_ResultSets AS r
       WHERE r.collection_Time >= @p_Collection_StartTime
	   AND r.collection_Time <= @p_Collection_EndTime
	   ORDER BY CheckDate DESC, (reads+writes) desc
GO
/*
	--	http://whoisactive.com/docs/16_morewaits/
	--	http://whoisactive.com/docs/28_access/
	--	http://whoisactive.com/docs/22_locks/

*/



-- select distinct CheckDate from dbo.BlitzFirst order by CheckDate DESC
DECLARE @p_CheckDate_StartDateTime datetimeoffset,
		@p_CheckDate_EndDateTime datetimeoffset,		
        @p_Collection_StartTime datetime,
		@p_Collection_EndTime datetime;

SET @p_CheckDate_StartDateTime = '2019-03-11 00:00:00.7090490 -05:00';
SET @p_CheckDate_EndDateTime = '2019-03-11 06:30:00.5379500 -05:00';

SET @p_Collection_StartTime = (SELECT MIN(collection_Time) AS collection_Time  FROM dbo.WhoIsActive_ResultSets WHERE collection_Time >= CAST(@p_CheckDate_StartDateTime AS DATETIME))
SET @p_Collection_EndTime = (SELECT MAX(collection_Time) AS collection_Time  FROM dbo.WhoIsActive_ResultSets WHERE collection_Time <= CAST(@p_CheckDate_EndDateTime AS DATETIME))

--SELECT * FROM DBA.dbo.BlitzFirst
--       WHERE CheckDate >= @p_CheckDate_StartDateTime
--			AND CheckDate <= @p_CheckDate_EndDateTime
--       ORDER BY CheckDate DESC, ID

SELECT collection_time as CheckDate, * FROM [DBA].[dbo].WhoIsActive_ResultSets AS r
       WHERE r.collection_Time >= @p_Collection_StartTime
	   AND r.collection_Time <= @p_Collection_EndTime
	   ORDER BY CheckDate DESC, (reads+writes) desc
GO