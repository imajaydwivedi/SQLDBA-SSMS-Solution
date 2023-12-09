-- select distinct CheckDate from dbo.BlitzFirst order by CheckDate DESC
USE DBA;

DECLARE @p_CheckDate datetimeoffset
SET @p_CheckDate = '2019-03-12 22:00:01.5485793 -04:00';

--	How to examine IO subsystem latencies from within SQL Server (Disk Latency)
	--	https://www.sqlskills.com/blogs/paul/how-to-examine-io-subsystem-latencies-from-within-sql-server/
	--	https://sqlperformance.com/2015/03/io-subsystem/monitoring-read-write-latency
	--	https://www.brentozar.com/blitz/slow-storage-reads-writes/
SELECT	
	LEFT ([PhysicalName], 2) AS [Drive],
    DatabaseName AS [DB],
    [PhysicalName],
	[SizeOnDiskMB],
    [ReadLatency] =
        CASE WHEN [num_of_reads] = 0
            THEN 0 ELSE ([io_stall_read_ms] / [num_of_reads]) END,
    [WriteLatency] =
        CASE WHEN [num_of_writes] = 0
            THEN 0 ELSE ([io_stall_write_ms] / [num_of_writes]) END,
    [Latency] =
        CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
            THEN 0 ELSE (([io_stall_read_ms]+[io_stall_write_ms]) / ([num_of_reads] + [num_of_writes])) END,
    [AvgBPerRead] =
        CASE WHEN [num_of_reads] = 0
            THEN 0 ELSE ([bytes_read] / [num_of_reads]) END,
    [AvgBPerWrite] =
        CASE WHEN [num_of_writes] = 0
            THEN 0 ELSE ([bytes_written] / [num_of_writes]) END,
    [AvgBPerTransfer] =
        CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
            THEN 0 ELSE
                (([bytes_read] + [bytes_written]) /
                ([num_of_reads] + [num_of_writes])) END    
FROM [dbo].[BlitzFirst_FileStats]
WHERE CheckDate = @p_CheckDate
--AND DatabaseName = 'tempdb'
ORDER BY [Latency] DESC
-- ORDER BY [ReadLatency] DESC
--ORDER BY [WriteLatency] DESC;
GO
