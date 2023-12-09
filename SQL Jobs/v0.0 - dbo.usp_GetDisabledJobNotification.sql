USE DBA
GO

IF OBJECT_ID('dbo.usp_GetDisabledJobNotification') IS NULL
	EXEC('CREATE PROCEDURE dbo.usp_GetDisabledJobNotification AS SELECT 1 AS dummy');
GO

ALTER PROCEDURE dbo.usp_GetDisabledJobNotification @p_JobName VARCHAR(125), 
													@p_EnableJob BIT = 1 , 
													@p_recipients VARCHAR(1000) = 'App-Team@contso.com', 
													@p_CopyRecepients VARCHAR(1000) = 'DBA@contso.com',
													@p_CallerInfo VARCHAR(500) = 'DBA - Enable Disabled Jobs',
													@p_Verbose BIT = 0
AS
BEGIN
	/*	Created By:			Ajay Dwivedi
		Version:			0.0
		Modification:		Dec 05, 2019 - First Check in of code
		Example:			EXEC dbo.usp_GetDisabledJobNotification 
										@p_JobName = 'TVAnytime', 
										@p_EnableJob = 1, 
										@p_recipients = 'App-Team@contso.com',
										@p_CopyRecepients = 'DBA@contso.com',
										@p_CallerInfo = 'DBA Enable Disabled Jobs',
										@p_Verbose = 0
	*/

	SET NOCOUNT ON;
	SET ANSI_WARNINGS OFF;

	IF @p_Verbose = 1
		PRINT 'Declaring local variables..';

	DECLARE @_mailSubject VARCHAR(125);
	DECLARE @_mailBody VARCHAR(2000);
	DECLARE @_isJobFound BIT = 0;
	DECLARE @_isJobDisabled BIT = 0;
	DECLARE @_UpdateJobReturnCode INT;
	DECLARE @_sendMailFlag BIT = 0;

	IF @p_Verbose = 1
		PRINT 'Checking if job named '''+@p_JobName+''' exists';
	IF EXISTS (SELECT * FROM msdb..sysjobs_view AS j WHERE j.name = @p_JobName)
		SET @_isJobFound = 1;

	IF @p_Verbose = 1
		PRINT 'Checking if job named '''+@p_JobName+''' is found in disabled state';
	IF @_isJobFound = 1 AND EXISTS (SELECT * FROM msdb..sysjobs_view AS j WHERE j.name = @p_JobName AND j.enabled = 0)
		SET @_isJobDisabled = 1;

	-- Process Main Logic
	IF @p_Verbose = 1
	BEGIN
		PRINT 'About to process Main Logic..'
		PRINT 'SELECT [@p_EnableJob] = @p_EnableJob, [@_isJobFound] = @_isJobFound, [@_isJobDisabled] = @_isJobDisabled;';
		SELECT [@p_EnableJob] = @p_EnableJob, [@_isJobFound] = @_isJobFound, [@_isJobDisabled] = @_isJobDisabled;
	END
	IF @p_EnableJob = 1 OR @_isJobFound = 0 OR @_isJobDisabled = 1
	BEGIN -- Process Main Logic
		IF @p_Verbose = 1
			PRINT 'Inside Main Logic..'

		IF @_isJobFound = 0 OR @_isJobDisabled = 1
		BEGIN
			IF @p_Verbose = 1
				PRINT 'Set @_sendMailFlag to 1'
			SET @_sendMailFlag = 1;		
		END
		ELSE
			RETURN;

		IF @_isJobFound = 0
		BEGIN
			IF @p_Verbose = 1
				PRINT 'Inside @_isJobFound = 0';
			SET @_mailSubject = 'Job '+QUOTENAME(@p_JobName)+' NOT found.'
			SET @_mailBody = 'Job '+QUOTENAME(@p_JobName)+' NOT found. Kindly revify the job name.' + '
		<p>
		Thanks & Regards,<br>
		SQL Alerts<br>
		DBA@contso.com<br>
		-- Alert Coming from SQL Agent Job ['+@p_CallerInfo+']<br>
		<p>';
		END
		ELSE IF @_isJobDisabled = 1
		BEGIN
			IF @p_Verbose = 1
				PRINT 'Inside @_isJobDisabled = 0';
			IF @p_EnableJob = 1
			BEGIN
				IF @p_Verbose = 1
					PRINT 'Inside @_isJobDisabled = 0, AND, @p_EnableJob = 1';

				-- changes the name, description, and disables status of the job NightlyBackups.  
				EXEC @_UpdateJobReturnCode = msdb.dbo.sp_update_job @job_name = @p_JobName, @enabled = 1;

				IF @_UpdateJobReturnCode = 0
				BEGIN
					IF @p_Verbose = 1
						PRINT '  Job successfully enabled.';

					SET @_mailSubject = 'Job '+QUOTENAME(@p_JobName)+' has been ENABLED.'
					SET @_mailBody = 'Job '+QUOTENAME(@p_JobName)+' was found in DISABLED state. It has been enabled successfully.' + '
		<p>
		Thanks & Regards,<br>
		SQL Alerts<br>
		DBA@contso.com<br>
		-- Alert Coming from SQL Agent Job ['+@p_CallerInfo+']<br>
		<p>';
				END
				ELSE
				BEGIN
					IF @p_Verbose = 1
						PRINT '  Job enabling failed.';

					SET @_mailSubject = 'Job '+QUOTENAME(@p_JobName)+' in DISABLED state.'
					SET @_mailBody = 'Job '+QUOTENAME(@p_JobName)+' is in DISABLED state. Enabling the job FAILED.<br><br>Kindly involve DBA to enable the jobs manually.' + '
		<p>
		Thanks & Regards,<br>
		SQL Alerts<br>
		DBA@contso.com<br>
		-- Alert Coming from SQL Agent Job ['+@p_CallerInfo+']<br>
		<p>';
				END
			END -- @p_EnableJob = 1
			ELSE
			BEGIN
				IF @p_Verbose = 1
					PRINT 'Inside @_isJobDisabled = 0. When only notification is to be sent';
				SET @_mailSubject = 'Job '+QUOTENAME(@p_JobName)+' in DISABLED state.'
				SET @_mailBody = 'Job '+QUOTENAME(@p_JobName)+' is in DISABLED state.<br><br>Kindly take appropriate action required.' + '
		<p>
		Thanks & Regards,<br>
		SQL Alerts<br>
		DBA@contso.com<br>
		-- Alert Coming from SQL Agent Job ['+@p_CallerInfo+']<br>
		<p>';
			END
		END

		IF @_sendMailFlag = 1
		BEGIN
			EXEC msdb.dbo.sp_send_dbmail  
					--@profile_name = @@SERVERNAME,  
					@body_format = 'HTML',
					--@recipients = 'ajay.dwivedi@contso.com',  
					@recipients = @p_recipients,
					@copy_recipients= @p_CopyRecepients,
					@body = @_mailBody,  
					@subject = @_mailSubject ;
		END
	END -- Process Main Logic
	ELSE
	BEGIN
		PRINT 'No issue found.'
	END
END
GO
