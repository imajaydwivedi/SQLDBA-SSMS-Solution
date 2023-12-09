DECLARE @query VARCHAR(1000)
	,@dbname VARCHAR(1000)
	,@count INT

SET NOCOUNT ON

DECLARE csr CURSOR FAST_FORWARD READ_ONLY
FOR
SELECT NAME
FROM master.dbo.sysdatabases

IF OBJECT_ID('tempdb..##loginfo') IS NOT NULL
	DROP TABLE ##loginfo;
CREATE TABLE ##loginfo (
	dbName VARCHAR(100)
	,VlfCounts INT
	)

OPEN csr

FETCH NEXT
FROM csr
INTO @dbname

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

	DROP TABLE #log_info

	INSERT ##loginfo
	VALUES (
		@dbname
		,@count
		)

	FETCH NEXT
	FROM csr
	INTO @dbname
END

CLOSE csr

DEALLOCATE csr

SELECT dbname
	,VlfCounts
FROM ##loginfo
--where VlfCounts >= 500
ORDER BY VlfCounts desc



--DROP TABLE ##loginfo