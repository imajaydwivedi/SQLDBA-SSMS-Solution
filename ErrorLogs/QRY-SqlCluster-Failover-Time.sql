-- https://sqlgeekspro.com/script-get-sql-cluster-failover-time-node-name/
CREATE TABLE #ErrorLog(
   LogDate DATETIME,
   ErrorSource NVARCHAR(MAX),
   ErrorMessage NVARCHAR(MAX)
)

CREATE TABLE #NumberOfLogs(
   ID INT PRIMARY KEY NOT NULL,
   LogDate DATETIME NOT NULL,
   LogFileSize bigint
)

INSERT INTO #NumberOfLogs(ID,LogDate,LogFileSize)
EXEC master.dbo.xp_enumerrorlogs

DECLARE @ErrorLogID INT

DECLARE cNumberOfLogs CURSOR FOR
   SELECT ID
   FROM #NumberOfLogs

OPEN cNumberOfLogs
FETCH NEXT FROM cNumberOfLogs INTO @ErrorLogID
   WHILE @@FETCH_STATUS = 0
   
   BEGIN
       INSERT INTO #ErrorLog(LogDate,ErrorSource,ErrorMessage)
       EXEC sp_readerrorlog @ErrorLogID, 1, 'NETBIOS'
        
       INSERT INTO #ErrorLog(LogDate,ErrorSource,ErrorMessage)
       EXEC sp_readerrorlog @ErrorLogID, 1, 'SQL Server is terminating'
       FETCH NEXT FROM cNumberOfLogs INTO @ErrorLogID
   END 
   
CLOSE cNumberOfLogs
DEALLOCATE cNumberOfLogs

SELECT LogDate, ErrorMessage FROM #ErrorLog

DROP TABLE #ErrorLog
DROP TABLE #NumberOfLogs