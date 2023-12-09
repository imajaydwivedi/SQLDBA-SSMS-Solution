USE [DBA]
GO

CREATE VIEW [dbo].[BlitzFirst_PerfmonStats_Deltas2] AS 
WITH RowDates as
(
        SELECT 
                ROW_NUMBER() OVER (ORDER BY [ServerName], [CheckDate]) ID,
                [CheckDate]
        FROM [dbo].[BlitzFirst_PerfmonStats]
        GROUP BY [ServerName], [CheckDate]
),
CheckDates as
(
        SELECT ThisDate.CheckDate,
               LastDate.CheckDate as PreviousCheckDate
        FROM RowDates ThisDate
        JOIN RowDates LastDate
        ON ThisDate.ID = LastDate.ID + 1
)
SELECT
       pMon.[ServerName]
      ,pMon.[CheckDate]
      ,pMon.[object_name]
      ,pMon.[counter_name]
      ,pMon.[instance_name]
      ,DATEDIFF(SECOND,pMonPrior.[CheckDate],pMon.[CheckDate]) AS ElapsedSeconds
      ,pMon.[cntr_value]
      ,pMon.[cntr_type]
      ,(pMon.[cntr_value] - pMonPrior.[cntr_value]) AS cntr_delta
 ,(pMon.cntr_value - pMonPrior.cntr_value) * 1.0 / DATEDIFF(ss, pMonPrior.CheckDate, pMon.CheckDate) AS cntr_delta_per_second
  FROM [dbo].[BlitzFirst_PerfmonStats] pMon
  INNER JOIN CheckDates Dates
  ON Dates.CheckDate = pMon.CheckDate
  JOIN [dbo].[BlitzFirst_PerfmonStats] pMonPrior
  ON  Dates.PreviousCheckDate = pMonPrior.CheckDate
      AND pMon.[ServerName]    = pMonPrior.[ServerName]   
      AND pMon.[object_name]   = pMonPrior.[object_name]  
      AND pMon.[counter_name]  = pMonPrior.[counter_name] 
      AND pMon.[instance_name] = pMonPrior.[instance_name]
    WHERE DATEDIFF(MI, pMonPrior.CheckDate, pMon.CheckDate) BETWEEN 1 AND 60;
GO

/****** Object:  View [dbo].[BlitzFirst_PerfmonStats_Actuals2]    Script Date: 2/21/2019 10:18:12 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[BlitzFirst_PerfmonStats_Actuals2] AS 
WITH PERF_AVERAGE_BULK AS
(
    SELECT ServerName,
           object_name,
           instance_name,
           counter_name,
           CASE WHEN CHARINDEX('(', counter_name) = 0 THEN counter_name ELSE LEFT (counter_name, CHARINDEX('(',counter_name)-1) END    AS   counter_join,
           CheckDate,
           cntr_delta
    FROM   [dbo].[BlitzFirst_PerfmonStats_Deltas2]
    WHERE  cntr_type IN(1073874176)
    AND cntr_delta <> 0
),
PERF_LARGE_RAW_BASE AS
(
    SELECT ServerName,
           object_name,
           instance_name,
           LEFT(counter_name, CHARINDEX('BASE', UPPER(counter_name))-1) AS counter_join,
           CheckDate,
           cntr_delta
    FROM   [dbo].[BlitzFirst_PerfmonStats_Deltas2]
    WHERE  cntr_type IN(1073939712)
    AND cntr_delta <> 0
),
PERF_AVERAGE_FRACTION AS
(
    SELECT ServerName,
           object_name,
           instance_name,
           counter_name,
           counter_name AS counter_join,
           CheckDate,
           cntr_delta
    FROM   [dbo].[BlitzFirst_PerfmonStats_Deltas2]
    WHERE  cntr_type IN(537003264)
    AND cntr_delta <> 0
),
PERF_COUNTER_BULK_COUNT AS
(
    SELECT ServerName,
           object_name,
           instance_name,
           counter_name,
           CheckDate,
           cntr_delta / ElapsedSeconds AS cntr_value
    FROM   [dbo].[BlitzFirst_PerfmonStats_Deltas2]
    WHERE  cntr_type IN(272696576, 272696320)
    AND cntr_delta <> 0
),
PERF_COUNTER_RAWCOUNT AS
(
    SELECT ServerName,
           object_name,
           instance_name,
           counter_name,
           CheckDate,
           cntr_value
    FROM   [dbo].[BlitzFirst_PerfmonStats_Deltas2]
    WHERE  cntr_type IN(65792, 65536)
)

SELECT NUM.ServerName,
       NUM.object_name,
       NUM.counter_name,
       NUM.instance_name,
       NUM.CheckDate,
       NUM.cntr_delta / DEN.cntr_delta AS cntr_value
       
FROM   PERF_AVERAGE_BULK AS NUM
       JOIN PERF_LARGE_RAW_BASE AS DEN ON NUM.counter_join = DEN.counter_join
                                          AND NUM.CheckDate = DEN.CheckDate
                                          AND NUM.ServerName = DEN.ServerName
                                          AND NUM.object_name = DEN.object_name
                                          AND NUM.instance_name = DEN.instance_name
                                          AND DEN.cntr_delta <> 0

UNION ALL

SELECT NUM.ServerName,
       NUM.object_name,
       NUM.counter_name,
       NUM.instance_name,
       NUM.CheckDate,
       CAST((CAST(NUM.cntr_delta as DECIMAL(19)) / DEN.cntr_delta) as decimal(23,3))  AS cntr_value
FROM   PERF_AVERAGE_FRACTION AS NUM
       JOIN PERF_LARGE_RAW_BASE AS DEN ON NUM.counter_join = DEN.counter_join
                                          AND NUM.CheckDate = DEN.CheckDate
                                          AND NUM.ServerName = DEN.ServerName
                                          AND NUM.object_name = DEN.object_name
                                          AND NUM.instance_name = DEN.instance_name
                                          AND DEN.cntr_delta <> 0
UNION ALL

SELECT ServerName,
       object_name,
       counter_name,
       instance_name,
       CheckDate,
       cntr_value
FROM   PERF_COUNTER_BULK_COUNT

UNION ALL

SELECT ServerName,
       object_name,
       counter_name,
       instance_name,
       CheckDate,
       cntr_value
FROM   PERF_COUNTER_RAWCOUNT;
GO

/****** Object:  View [dbo].[BlitzFirst_FileStats_Deltas2]    Script Date: 2/21/2019 10:18:12 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[BlitzFirst_FileStats_Deltas2] AS 
WITH RowDates as
(
        SELECT 
                ROW_NUMBER() OVER (ORDER BY [ServerName], [CheckDate]) ID,
                [CheckDate]
        FROM [dbo].[BlitzFirst_FileStats]
        GROUP BY [ServerName], [CheckDate]
),
CheckDates as
(
        SELECT ThisDate.CheckDate,
               LastDate.CheckDate as PreviousCheckDate
        FROM RowDates ThisDate
        JOIN RowDates LastDate
        ON ThisDate.ID = LastDate.ID + 1
)
     SELECT f.ServerName,
            f.CheckDate,
            f.DatabaseID,
            f.DatabaseName,
            f.FileID,
            f.FileLogicalName,
            f.TypeDesc,
            f.PhysicalName,
            f.SizeOnDiskMB,
            DATEDIFF(ss, fPrior.CheckDate, f.CheckDate) AS ElapsedSeconds,
            (f.SizeOnDiskMB - fPrior.SizeOnDiskMB) AS SizeOnDiskMBgrowth,
            (f.io_stall_read_ms - fPrior.io_stall_read_ms) AS io_stall_read_ms,
            io_stall_read_ms_average = CASE
                                           WHEN(f.num_of_reads - fPrior.num_of_reads) = 0
                                           THEN 0
                                           ELSE(f.io_stall_read_ms - fPrior.io_stall_read_ms) /     (f.num_of_reads   -           fPrior.num_of_reads)
                                       END,
            (f.num_of_reads - fPrior.num_of_reads) AS num_of_reads,
            (f.bytes_read - fPrior.bytes_read) / 1024.0 / 1024.0 AS megabytes_read,
            (f.io_stall_write_ms - fPrior.io_stall_write_ms) AS io_stall_write_ms,
            io_stall_write_ms_average = CASE
                                            WHEN(f.num_of_writes - fPrior.num_of_writes) = 0
                                            THEN 0
                                            ELSE(f.io_stall_write_ms - fPrior.io_stall_write_ms) /         (f.num_of_writes   -       fPrior.num_of_writes)
                                        END,
            (f.num_of_writes - fPrior.num_of_writes) AS num_of_writes,
            (f.bytes_written - fPrior.bytes_written) / 1024.0 / 1024.0 AS megabytes_written
     FROM   [dbo].[BlitzFirst_FileStats] f
            INNER JOIN CheckDates DATES ON f.CheckDate = DATES.CheckDate
            INNER JOIN [dbo].[BlitzFirst_FileStats] fPrior ON f.ServerName =                 fPrior.ServerName
                                                              AND f.DatabaseID = fPrior.DatabaseID
                                                              AND f.FileID = fPrior.FileID
                                                              AND fPrior.CheckDate =   DATES.PreviousCheckDate

     WHERE  f.num_of_reads >= fPrior.num_of_reads
            AND f.num_of_writes >= fPrior.num_of_writes
            AND DATEDIFF(MI, fPrior.CheckDate, f.CheckDate) BETWEEN 1 AND 60;
GO

/****** Object:  View [dbo].[BlitzFirst_WaitStats_Deltas2]    Script Date: 2/21/2019 10:18:12 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[BlitzFirst_WaitStats_Deltas2] AS 
WITH RowDates as
(
        SELECT 
                ROW_NUMBER() OVER (ORDER BY [ServerName], [CheckDate]) ID,
                [CheckDate]
        FROM [dbo].[BlitzFirst_WaitStats]
        GROUP BY [ServerName], [CheckDate]
),
CheckDates as
(
        SELECT ThisDate.CheckDate,
               LastDate.CheckDate as PreviousCheckDate
        FROM RowDates ThisDate
        JOIN RowDates LastDate
        ON ThisDate.ID = LastDate.ID + 1
)
SELECT w.ServerName, w.CheckDate, w.wait_type, COALESCE(wc.WaitCategory, 'Other') AS WaitCategory, COALESCE(wc.Ignorable,0) AS Ignorable
, DATEDIFF(ss, wPrior.CheckDate, w.CheckDate) AS ElapsedSeconds
, (w.wait_time_ms - wPrior.wait_time_ms) AS wait_time_ms_delta
, (w.wait_time_ms - wPrior.wait_time_ms) / 60000.0 AS wait_time_minutes_delta
, (w.wait_time_ms - wPrior.wait_time_ms) / 1000.0 / DATEDIFF(ss, wPrior.CheckDate, w.CheckDate) AS wait_time_minutes_per_minute
, (w.signal_wait_time_ms - wPrior.signal_wait_time_ms) AS signal_wait_time_ms_delta
, (w.waiting_tasks_count - wPrior.waiting_tasks_count) AS waiting_tasks_count_delta
FROM [dbo].[BlitzFirst_WaitStats] w
INNER JOIN CheckDates Dates
ON Dates.CheckDate = w.CheckDate
INNER JOIN [dbo].[BlitzFirst_WaitStats] wPrior ON w.ServerName = wPrior.ServerName AND w.wait_type = wPrior.wait_type AND Dates.PreviousCheckDate = wPrior.CheckDate
LEFT OUTER JOIN [dbo].[BlitzFirst_WaitStats_Categories] wc ON w.wait_type = wc.WaitType
WHERE DATEDIFF(MI, wPrior.CheckDate, w.CheckDate) BETWEEN 1 AND 60
AND [w].[wait_time_ms] >= [wPrior].[wait_time_ms];
GO


