USE DBA;

-- select distinct CheckDate from dbo.BlitzFirst order by CheckDate DESC

DECLARE @p_CheckDate datetimeoffset
SET @p_CheckDate = '2019-03-07 05:00:00.7291387 -06:00';

--	How to examine IO subsystem latencies from within SQL Server (Disk Latency)
	--	https://www.sqlskills.com/blogs/paul/how-to-examine-io-subsystem-latencies-from-within-sql-server/
	--	https://sqlperformance.com/2015/03/io-subsystem/monitoring-read-write-latency
	--	https://www.brentozar.com/blitz/slow-storage-reads-writes/
SELECT DATEDIFF(MINUTE,d.CheckDate_Lower, fs.CheckDate) AS [Delta(min)], * 
FROM [dbo].[BlitzFirst_FileStats_Deltas2] as fs
CROSS JOIN (SELECT MAX(CheckDate) as CheckDate_Lower FROM BlitzFirst_FileStats as i WHERE i.CheckDate < @p_CheckDate) as d
WHERE CheckDate = @p_CheckDate
	ORDER BY (io_stall_read_ms_average+io_stall_write_ms_average) desc
GO