$server = 'YourDbServerName'
$tsqlQuery = @"
DECLARE @p_CheckDate datetimeoffset
             ,@p_Collection_Time datetime;

SET @p_CheckDate = '2019-03-07 05:00:00.7291387 -06:00';
SELECT @p_CheckDate as [@p_CheckDate], * FROM DBA.dbo.BlitzFirst
       WHERE CheckDate = @p_CheckDate
       --ORDER BY CheckDate DESC
"@;

$rs = Invoke-DbaQuery -SqlInstance $server -Query $tsqlQuery;
$rs | Export-Excel -Path 'C:\MS-OneDrive\OneDrive - contso Inc\Attachments\Daily Tasks\2019 March\Galaxy-Slowness-Mar07-1630-IST.xlsx' -WorkSheetname 'BlitzFirst';

$tsqlQuery = @"
DECLARE @p_CheckDate datetimeoffset
             ,@p_Collection_Time datetime;

SET @p_CheckDate = '2019-03-07 05:00:00.7291387 -06:00';
SET @p_Collection_Time = (SELECT MIN(collection_Time) AS collection_Time  FROM [DBA].[dbo].[WhoIsActive_ResultSets] WHERE collection_Time >= CAST(@p_CheckDate AS DATETIME))
SELECT collection_Time as [@p_CheckDate], * FROM [DBA].[dbo].[WhoIsActive_ResultSets] AS r
       WHERE r.collection_Time = @p_Collection_Time;
"@;

$rs = Invoke-DbaQuery -SqlInstance $server -Query $tsqlQuery;
$rs | Export-Excel -Path 'C:\MS-OneDrive\OneDrive - contso Inc\Attachments\Daily Tasks\2019 March\Galaxy-Slowness-Mar07-1630-IST.xlsx' -WorkSheetname 'WhoIsActive_ResultSets';
