/*
	2022-Nov-02 - Initial Draft - Setup Alerts for AG

	Prerequisites:
		SQLAgent Mail Profile should be enabled/set

	References:
		https://www.mssqltips.com/sqlservertip/3489/configure-sql-server-alerts-and-notifications-for-alwayson-availability-groups/
		https://www.sqlservercentral.com/forums/topic/how-to-set-alert-when-alwayson-high-availabilty-database-stop-synchronizing#:~:text=There%20are%20a%20whole%20set%20of%20agent%20alerts%20that%20you%20can%20define%20for%20AG
		https://www.sqlrx.com/alwayson-monitoring-and-alerting/
		https://blog.waynesheffield.com/wayne/archive/2020/08/availability-group-issues-fixed-with-alerts/
*/

SET NOCOUNT ON;

-- Parameters
DECLARE @operatorName SYSNAME = 'SQLAgentService';

-- Declare local variables
DECLARE @alertName SYSNAME;
DECLARE @thisErrorNumber VARCHAR(6);

-- Declare variable tables
DECLARE @errorNumbers TABLE (ErrorNumber VARCHAR(6), AlertName VARCHAR(50));

-- List all the Errors Messages to Track
INSERT INTO @errorNumbers
VALUES	('1480', '(dba) AG Role Change - failover')
      , ('976', '(dba) Database Not Accessible')
      , ('983', '(dba) Database Role Resolving')
      , ('3402' , '(dba) Database Restoring')
      , ('19406', '(dba) AG Replica Changed States')
      , ('35206', '(dba) Connection Timeout')
      , ('35250', '(dba) Connection to Primary Inactive')
      , ('35264', '(dba) Data Movement Suspended')
      , ('35273', '(dba) Database Inaccessible')
      , ('35274', '(dba) Database Recovery Pending')
      , ('35275', '(dba) Database in Suspect State')
      , ('35276', '(dba) Database Out of Sync')
      , ('41091', '(dba) Replica Going Offline')
      , ('41131', '(dba) Failed to Bring AG Online')
      , ('41142', '(dba) Replica Cannot Become Primary')
      , ('41406', '(dba) AG Not Ready for Auto Failover')
      , ('41414', '(dba) Secondary Not Connected');

DECLARE cur_ForEachErrorNumber CURSOR LOCAL FAST_FORWARD FOR
	SELECT *
	FROM @errorNumbers;

OPEN cur_ForEachErrorNumber;

FETCH NEXT FROM cur_ForEachErrorNumber INTO @thisErrorNumber, @alertName;

WHILE @@fetch_status = 0
BEGIN
	IF NOT EXISTS (
			SELECT *
			FROM msdb.dbo.sysalerts s
			WHERE s.message_id = @thisErrorNumber
			)
	BEGIN
		EXECUTE msdb.dbo.sp_add_alert @name = @alertName, @message_id = @thisErrorNumber, @severity = 0, @enabled = 1, @delay_between_responses = 0, @include_event_description_in = 1, @job_id = N'00000000-0000-0000-0000-000000000000';

		EXECUTE msdb.dbo.sp_add_notification @alert_name = @alertName, @operator_name = @operatorName, @notification_method = 1;

		RAISERROR ('Alert ''%s'' for error number %s created.', - 1, - 1, @alertName, @thisErrorNumber)
		WITH NOWAIT;
	END

	FETCH NEXT
	FROM cur_ForEachErrorNumber
	INTO @thisErrorNumber, @alertName;
END

--==== Close/Deallocate cursor
CLOSE cur_ForEachErrorNumber;

DEALLOCATE cur_ForEachErrorNumber;
go


