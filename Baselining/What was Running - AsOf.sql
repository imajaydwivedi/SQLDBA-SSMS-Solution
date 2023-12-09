USE DBA
GO
/*
	--	http://whoisactive.com/docs/16_morewaits/
	--	http://whoisactive.com/docs/28_access/
	--	http://whoisactive.com/docs/22_locks/

*/

-- March 7, 2019 , 16:30 IST 
-- select distinct CheckDate from dbo.BlitzFirst order by CheckDate DESC
DECLARE @p_CheckDate datetimeoffset
             ,@p_Collection_Time datetime;
/*
SET @p_CheckDate = '2019-03-07 05:00:00.7291387 -06:00';
SELECT @p_CheckDate as [@p_CheckDate], * FROM DBA.dbo.BlitzFirst
       WHERE CheckDate = @p_CheckDate
       --ORDER BY CheckDate DESC
*/
SET @p_CheckDate = '2019-03-07 05:00:00.7291387 -06:00';
SELECT @p_CheckDate as [@p_CheckDate], * FROM DBA.dbo.BlitzFirst
       WHERE CheckDate = @p_CheckDate
       --ORDER BY CheckDate DESC

SET @p_CheckDate = '2019-03-07 05:00:00.7291387 -06:00';
SET @p_Collection_Time = (SELECT MIN(collection_Time) AS collection_Time  FROM [DBA].[dbo].[WhoIsActive_ResultSets] WHERE collection_Time >= CAST(@p_CheckDate AS DATETIME))
SELECT collection_Time as [@p_CheckDate], * FROM [DBA].[dbo].[WhoIsActive_ResultSets] AS r
       WHERE r.collection_Time = @p_Collection_Time;

/*
SET @p_CheckDate = '2019-03-06 05:00:00.7171564 -06:00';
SET @p_Collection_Time = (SELECT MIN(collection_Time) AS collection_Time  FROM [DBA].[dbo].[WhoIsActive_ResultSets] WHERE collection_Time >= CAST(@p_CheckDate AS DATETIME))
SELECT collection_Time as [@p_CheckDate], * FROM [DBA].[dbo].[WhoIsActive_ResultSets] AS r
       WHERE r.collection_Time = @p_Collection_Time;
*/
