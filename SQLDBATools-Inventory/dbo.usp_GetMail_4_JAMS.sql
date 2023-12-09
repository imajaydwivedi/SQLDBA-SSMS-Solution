USE SQLDBATools
GO

--	EXEC SQLDBATools..[usp_GetMail_4_JAMS] @p_Option = 'JAMSEntry' ,@p_recipients = 'ajay.dwivedi@contso.com'
IF OBJECT_ID('dbo.usp_GetMail_4_JAMS') IS NULL
	EXEC ('CREATE PROCEDURE dbo.usp_GetMail_4_JAMS AS SELECT 1 AS DummyToBeReplace;');
GO
ALTER PROCEDURE [dbo].[usp_GetMail_4_JAMS] ( 
						@p_Option VARCHAR(50) = 'JAMSEntry'
						,@p_Verbose BIT = 0
						,@p_DefaultHTMLStyle VARCHAR(100) = 'GreenBackgroundHeader'
						,@p_recipients VARCHAR(255) = NULL
					)
AS
BEGIN
	/*	Created By:		Ajay Dwivedi
		Created Date:	01-Sep-2018
		Purpose:		This procedure accepts category for mailer, and send mail for SQLDBATools
	*/
	SET NOCOUNT ON;

	IF @p_Verbose = 1
		PRINT 'Declaring Variables';
	DECLARE @mailHTML  NVARCHAR(MAX) ;
	DECLARE @subject VARCHAR(200);
	DECLARE @htmlTable VARCHAR(MAX);
	DECLARE @tableHeader VARCHAR(MAX);
	DECLARE @cssStyle_GreenBackgroundHeader VARCHAR(MAX);
	DECLARE @htmlBody VARCHAR(MAX);
	DECLARE @tableData VARCHAR(MAX);

	IF (@p_Option = 'JAMSEntry')
	BEGIN
		SET @tableHeader = '<tr><th>ServerName</th><th>Setup Name</th><th>Current State</th><th>Schedule Time</th><th>Elapsed Time(Minutes)</th></tr>';
		SELECT	@tableData = COALESCE(@tableData+'<tr>'+'<td>'+s.ServerName+'</td><td>'+s.Setup+'</td><td>'+(case when j.CurrentState = 'ResourceWait' then j.CurrentState else j.Description end)+'</td><td>'+cast(s.HoldTime as varchar(30))+'</td><td>'+cast(s.ElapsedTime/1000/60 as varchar(50))+'</td></tr>',
												'<tr><td>'+s.ServerName+'</td><td>'+s.Setup+'</td><td>'+(case when j.CurrentState = 'ResourceWait' then j.CurrentState else j.Description end)+'</td><td>'+cast(s.HoldTime as varchar(30))+'</td><td>'+cast(s.ElapsedTime/1000/60 as varchar(50))+'</td></tr>' )
		FROM	Staging.JAMSEntry AS s
		INNER JOIN
				Staging.JAMSEntry AS j
			ON	s.SetupID = j.SetupID
			AND	s.JobName like ('%'+s.ServerName+'%')
			AND j.JobName = 'Execute AppSync Process'
		WHERE	j.CurrentState = 'ResourceWait'
			OR	(j.CurrentState = 'Completed' AND j.[Description] = 'Unknown error (0xffffffff)' AND s.CurrentState = 'Executing');

		IF @tableData IS NULL
		BEGIN
			PRINT 'No Stuck JAMS job found.';
			RETURN;
		END

	END

	SET @htmlTable = '<table border="1" class="'+@p_DefaultHTMLStyle+'">'+@tableHeader+@tableData+'</table>';

	IF @subject IS NULL
		SET @subject = 'JAMS Issue - One or More Stuck Execution';

	SET @htmlBody = 'Hi DBA Team,
<br><br>
Below JAMS Setup(s) have entered into Stuck state:-
<br><p>
'+@htmlTable+'
</p>
Kindly take appropriate action immediately.
<br><br><br>

Regards,<br>
SQL Alerts
';  

	IF @p_Verbose = 1
		PRINT 'Set value for @subject';
	SET @subject = @subject + ' - '+CAST(CAST(GETDATE() AS DATE) AS VARCHAR(20));
	IF @p_Verbose = 1
		PRINT	CHAR(13)+CHAR(10)+'Value for @subject = '+ISNULL(@subject,'<<NULL>>');

	IF @p_Verbose = 1
		PRINT 'Set value for @cssStyle_GreenBackgroundHeader';
	SET @cssStyle_GreenBackgroundHeader = N'
	<style>
	.GreenBackgroundHeader {
		font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
		border-collapse: collapse;
		width: 100%;
	}

	.GreenBackgroundHeader td, .GreenBackgroundHeader th {
		border: 1px solid #ddd;
		padding: 8px;
	}

	.GreenBackgroundHeader tr:nth-child(even){background-color: #f2f2f2;}

	.GreenBackgroundHeader tr:hover {background-color: #ddd;}

	.GreenBackgroundHeader th {
		padding-top: 12px;
		padding-bottom: 12px;
		text-align: left;
		background-color: #4CAF50;
		color: white;
	}
	</style>';
	IF @p_Verbose = 1
		PRINT	CHAR(13)+CHAR(10)+'Value for @cssStyle_GreenBackgroundHeader = '+ISNULL(@cssStyle_GreenBackgroundHeader,'<<NULL>>');
	
	IF @p_Verbose = 1
		PRINT 'Set value for @htmlBody using @subject, @p_DefaultHTMLStyle, @columnList4TableHeader and @columnList4TableData values.';

	IF @p_Verbose = 1
		PRINT 'Set value for @mailHTML using @cssStyle_GreenBackgroundHeader and @htmlBody values.';
	SET @mailHTML =  @cssStyle_GreenBackgroundHeader + @htmlBody;

	IF (@p_recipients IS NULL) 
	BEGIN
		SET @p_recipients = 'ajay.dwivedi@contso.com';
	END

	EXEC msdb..sp_send_dbmail 
		@recipients = @p_recipients,  
		@subject = @subject,  
		@body = @mailHTML,  
		@body_format = 'HTML' ; 
END -- Procedure

GO
