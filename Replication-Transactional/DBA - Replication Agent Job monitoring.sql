    DECLARE @profile_name VARCHAR(100) = @@servername
    DECLARE @strsubject VARCHAR(100)
    DECLARE @tableHTML NVARCHAR(max)
    DECLARE @EmailRecipients VARCHAR(max) = 'sqlagentservice@gmail.com'
 
    CREATE TABLE #agentHistory (
        ServerName NVARCHAR (64)
        ,Publication NVARCHAR (64)
        ,AgentName NVARCHAR(512)
        ,LastMsgTime DATETIME
        )
 
;WITH CTE ( server_name,publication,agent_name,last_update) AS
( 
SELECT
        srvr.srvname
        ,agent.publication 
        ,agent.NAME
        ,MAX(history.TIME)
    FROM MSdistribution_agents agent
    INNER JOIN msdistribution_history history ON history.agent_id = agent.id
    INNER JOIN sys.sysservers srvr on srvr.srvid = agent.subscriber_id
    GROUP BY srvr.srvname,agent.publication,agent.NAME
    )
    INSERT INTO #agentHistory
    SELECT server_name,publication,agent_name,last_update from CTE
    WHERE last_update < dateadd(MINUTE, - 30, getdate())
 
    IF EXISTS (
            SELECT *
            FROM #agentHistory
            )
    BEGIN
        SELECT @strsubject = 'Replication Agent Alert ' + convert(VARCHAR(17), getdate(), 113) + ' ***'
 
        SET @tableHTML = N'<H1>Replication Agent has not Logged a Message</H1>' + N'<h3>One or more agents have not logged an update in the last 30 minutes</h3>' + N'<table border="1">' + N'<tr><th>Server Name</th>'+ N'<th>Publication</th>'+ N'<th>Agent Name</th>' +  N'<th>Last Updated Time</th>' + '</tr>' + cast((
                    SELECT td = AH.ServerName
                        ,''
                        ,td = AH.Publication
                        ,''
                        ,td = AH.AgentName
                        ,''
                        ,td = AH.LastMsgTime
                        ,''
                    FROM #agentHistory AH
                    FOR XML path('tr')
                        ,type
                    ) AS NVARCHAR(max)) + N'</table>' + CHAR (10) + CHAR (13) +
 
                    '<p> In order to resolve this, log onto the server, start up SQL Server and find the job under "SQL Server Agent -> Jobs". If job is stopped, right click and select "start job at step". The job will start running. Do not wait for it to complete as the job runs continuously. If the same jobs alerts again raise the issue with the DBA Team. '
 
        EXEC msdb.dbo.sp_send_dbmail @recipients = @EmailRecipients
            ,@subject = @strsubject
            ,@body = @tableHTML
            ,@body_format = 'HTML'
            ,@profile_name = @profile_name
    END
 
DECLARE @COUNT INT
DECLARE @PostLog BIT = 0
DECLARE @@SERVER_NAME VARCHAR (128)
DECLARE @@AGENTNAME VARCHAR (128) = ''
DECLARE @@PUBLICATION VARCHAR (128) = ''
 
DECLARE @@MESSAGE varchar(2000)
DECLARE @@MSG_ARRAY varchar (2000) = ''
 
SELECT @COUNT = COUNT (*) FROM #agentHistory
SELECT @PostLog = CASE WHEN @COUNT > 0 THEN 1 ELSE 0 END
WHILE @COUNT > 0
BEGIN
 
SELECT @@AGENTNAME = MAX (Ah.AgentName) FROM #agentHistory AH
 
SELECT @@MESSAGE = 'Agents have not logged a message. Log on to server, open SQL Server Management Studio and start job if not running. If job continues to alert that it has stopped then contact DBA Team.
If job is running then monitor and close ticket when agents no longer alert.'
SELECT @@MSG_ARRAY =  @@AGENTNAME + ' '  + CHAR(10) + CHAR(13) + @@MSG_ARRAY + ' '
 
SET @COUNT = @COUNT - 1
 
DELETE FROM #agentHistory where AgentName = @@AGENTNAME
 
SELECT @@MESSAGE = @@MESSAGE + CHAR(10) + CHAR(13) +@@MSG_ARRAY 
 
END
 
IF @PostLog = 1
 
BEGIN
 
USE master
EXEC xp_logevent 68320, @@MESSAGE, error
 
END
 
DROP TABLE #agentHistory