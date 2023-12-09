DECLARE @p_dbName VARCHAR(1000);
DECLARE @p_HighVLFThreshold INT;
--SET @p_dbName = 'DBA'
SET @p_HighVLFThreshold = 500;

SET NOCOUNT ON
DECLARE @query VARCHAR(1000)
	,@dbname VARCHAR(1000)
	,@count INT;

IF OBJECT_ID('tempdb..##loginfo') IS NOT NULL
	DROP TABLE ##loginfo;
CREATE TABLE ##loginfo (
	dbName VARCHAR(100)
	,VlfCounts INT
	)

DECLARE csr CURSOR FAST_FORWARD READ_ONLY
FOR
	SELECT NAME
	FROM master.dbo.sysdatabases as  d
	WHERE @p_dbName IS NULL
	OR d.name = @p_dbName;

OPEN csr
FETCH NEXT FROM csr INTO @dbname;

WHILE (@@FETCH_STATUS = 0)
BEGIN
	CREATE TABLE #log_info (
		fileid TINYINT
		,file_size BIGINT
		,start_offset BIGINT
		,FSeqNo INT
		,[status] TINYINT
		,parity TINYINT
		,create_lsn NUMERIC(25, 0)
		)

	SET @query = 'DBCC loginfo (' + '''' + @dbname + ''') '

	INSERT INTO #log_info
	EXEC (@query)

	SET @count = @@rowcount

	DROP TABLE #log_info;

	INSERT ##loginfo
	VALUES (@dbname	,@count	)

	FETCH NEXT FROM csr INTO @dbname;
END

CLOSE csr;
DEALLOCATE csr;

/* Get VLF Counts */
SELECT dbname
	,VlfCounts
FROM ##loginfo
WHERE VlfCounts >= @p_HighVLFThreshold
ORDER BY VlfCounts DESC;

DECLARE @tsqlShrinkLogFile NVARCHAR(MAX);
SET @tsqlShrinkLogFile = '';


DECLARE csrHighVLFDbs CURSOR FAST_FORWARD READ_ONLY
FOR
	SELECT dbname --,VlfCounts
	FROM ##loginfo
	WHERE VlfCounts >= @p_HighVLFThreshold
	ORDER BY VlfCounts DESC

OPEN csrHighVLFDbs
FETCH NEXT FROM csrHighVLFDbs INTO @dbname;

WHILE (@@FETCH_STATUS = 0)
BEGIN
	
	print @dbname;
	FETCH NEXT FROM csrHighVLFDbs INTO @dbname;
END

CLOSE csrHighVLFDbs;
DEALLOCATE csrHighVLFDbs;

--DROP TABLE ##loginfo