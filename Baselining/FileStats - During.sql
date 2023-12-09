USE DBA;
-- select distinct CheckDate from dbo.BlitzFirst order by CheckDate DESC

DECLARE @p_CheckDate_Lower datetimeoffset,
		@p_CheckDate_Upper datetimeoffset
SET @p_CheckDate_Lower = '2019-03-12 00:00:01.1477067 -05:00';
SET @p_CheckDate_Upper = '2019-03-12 06:30:00.7263793 -05:00';

--select * FROM [dbo].[BlitzFirst_FileStats] f where f.CheckDate = @p_CheckDate_Lower
--select * from [dbo].[BlitzFirst_FileStats] f where f.CheckDate = @p_CheckDate_Upper

;WITH RowDates as
(
        SELECT 
                ROW_NUMBER() OVER (ORDER BY [ServerName], [CheckDate]) ID,
                [CheckDate]
        FROM [dbo].[BlitzFirst_FileStats]
		WHERE CheckDate = (SELECT MIN(CheckDate) as CheckDate FROM [dbo].[BlitzFirst_FileStats] AS D WHERE CheckDate >= @p_CheckDate_Lower)
		OR CheckDate = (SELECT MAX(CheckDate) as CheckDate FROM [dbo].[BlitzFirst_FileStats] AS D WHERE CheckDate <= @p_CheckDate_Upper)
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
,T_Final AS
(
     SELECT @p_CheckDate_Lower AS [@p_CheckDate_Lower], @p_CheckDate_Upper AS [@p_CheckDate_Upper],
		WaitsDuration = DATEDIFF(MINUTE,@p_CheckDate_Lower,@p_CheckDate_Upper),
			f.ServerName,
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
)
SELECT * FROM T_Final
	ORDER BY (io_stall_read_ms_average + io_stall_write_ms_average) desc
GO


-- select distinct CheckDate from dbo.BlitzFirst order by CheckDate DESC

DECLARE @p_CheckDate_Lower datetimeoffset,
		@p_CheckDate_Upper datetimeoffset
SET @p_CheckDate_Lower = '2019-03-11 00:00:00.7090490 -05:00';
SET @p_CheckDate_Upper = '2019-03-11 06:30:00.5379500 -05:00';

--select * FROM [dbo].[BlitzFirst_FileStats] f where f.CheckDate = @p_CheckDate_Lower
--select * from [dbo].[BlitzFirst_FileStats] f where f.CheckDate = @p_CheckDate_Upper

;WITH RowDates as
(
        SELECT 
                ROW_NUMBER() OVER (ORDER BY [ServerName], [CheckDate]) ID,
                [CheckDate]
        FROM [dbo].[BlitzFirst_FileStats]
		WHERE CheckDate = (SELECT MIN(CheckDate) as CheckDate FROM [dbo].[BlitzFirst_FileStats] AS D WHERE CheckDate >= @p_CheckDate_Lower)
		OR CheckDate = (SELECT MAX(CheckDate) as CheckDate FROM [dbo].[BlitzFirst_FileStats] AS D WHERE CheckDate <= @p_CheckDate_Upper)
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

,T_Final AS
(
     SELECT @p_CheckDate_Lower AS [@p_CheckDate_Lower], @p_CheckDate_Upper AS [@p_CheckDate_Upper],
		WaitsDuration = DATEDIFF(MINUTE,@p_CheckDate_Lower,@p_CheckDate_Upper),
			f.ServerName,
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
)
SELECT * FROM T_Final
	ORDER BY (io_stall_read_ms_average + io_stall_write_ms_average) desc
GO

