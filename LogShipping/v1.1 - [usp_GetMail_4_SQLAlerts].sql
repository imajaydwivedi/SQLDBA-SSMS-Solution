USE DBA
GO

IF OBJECT_ID('dbo.usp_GetMail_4_SQLAlerts') IS NULL
	EXEC ('CREATE PROCEDURE dbo.usp_GetMail_4_SQLAlerts AS SELECT 1 AS DummyToBeReplace;');
GO
ALTER PROCEDURE [dbo].[usp_GetMail_4_SQLAlerts] ( 
						@p_Option VARCHAR(50) = 'JobBlockers'
						,@p_JobName VARCHAR(255) = 'DBA Log Walk - Restore Staging as Staging'
						,@p_Verbose BIT = 0
						,@p_DefaultHTMLStyle VARCHAR(100) = 'GreenBackgroundHeader'
						,@p_recipients VARCHAR(255) = NULL
					)
AS
BEGIN
	/*	Created By:		Ajay Dwivedi
		Version:		v1.0
		Purpose:		29-Apr-2019 - This procedure accepts category for mailer, and send mail for SQLAlerts
	*/
	SET NOCOUNT ON;

	IF @p_Verbose = 1
		PRINT 'Declaring Variables';
	DECLARE @mailHTML  NVARCHAR(MAX) ;
	DECLARE @subject VARCHAR(200);
	DECLARE @tableName VARCHAR(125);
	DECLARE @columnList4TableHeader VARCHAR(MAX);
	DECLARE @columnList4TableData VARCHAR(MAX);
	DECLARE @cssStyle_GreenBackgroundHeader VARCHAR(MAX);
	DECLARE @htmlBody VARCHAR(MAX);
	DECLARE @sqlString VARCHAR(MAX);
	DECLARE @data4TableData TABLE ( TableData VARCHAR(MAX) );
	DECLARE @queryFilter VARCHAR(2000);

	IF @p_Verbose = 1
		PRINT 'Set value for @tableName';
	IF (@p_Option = 'JobBlockers')
	BEGIN
		SET @tableName = 'dbo.JobBlockers';
		--SET @queryFilter = ' AND UsedSpacePercent > 80 ';
	END

	IF @p_Verbose = 1
	BEGIN
		PRINT	CHAR(13)+CHAR(10)+'Value for @tableName = '+ISNULL(@tableName,'<<NULL>>');
		PRINT	CHAR(13)+CHAR(10)+'Value for @queryFilter = '+ISNULL(@queryFilter,'<<NULL>>');
	END

	IF @p_Verbose = 1
		PRINT 'Set value for @columnList4TableHeader';
	-- Get table headers <th> data for Table <table>
	SELECT	@columnList4TableHeader = COALESCE(@columnList4TableHeader ,'') + ('<th>'+COLUMN_NAME+'</th>'+CHAR(13)+CHAR(10))
	FROM	INFORMATION_SCHEMA.COLUMNS as c
	WHERE	TABLE_SCHEMA+'.'+c.TABLE_NAME = @tableName
		AND	c.COLUMN_NAME NOT IN ('ID');
	IF @p_Verbose = 1
		PRINT	CHAR(13)+CHAR(10)+'Value for @columnList4TableHeader = '+ISNULL(@columnList4TableHeader,'<<NULL>>');

	IF @p_Verbose = 1
		PRINT 'Set value for @columnList4TableData';
	-- Get row (tr) data for Table <table>
	SELECT	@columnList4TableData = COALESCE(@columnList4TableData+', '''','+CHAR(13)+CHAR(10) ,'') + 
			('td = '+CASE WHEN COLUMN_NAME = 'BLOCKING_TREE' THEN 'LEFT(ISNULL('+COLUMN_NAME+','' ''),150)'
						WHEN DATA_TYPE = 'xml' THEN 'ISNULL(LEFT(CAST('+COLUMN_NAME+' AS varchar(max)),150),'' '')'
						WHEN DATA_TYPE NOT LIKE '%char' AND IS_NULLABLE = 'YES' THEN 'ISNULL(CAST('+COLUMN_NAME+' AS varchar(125)),'' '')'
						WHEN DATA_TYPE NOT LIKE '%char' THEN 'CAST('+COLUMN_NAME+' AS VARCHAR(125))'
						WHEN IS_NULLABLE = 'YES' THEN 'ISNULL('+COLUMN_NAME+','' '')'
						ELSE COLUMN_NAME
						END)
	FROM	INFORMATION_SCHEMA.COLUMNS as c
	WHERE	TABLE_SCHEMA+'.'+c.TABLE_NAME = @tableName
		AND	c.COLUMN_NAME NOT IN ('ID');
	IF @p_Verbose = 1
	BEGIN
		PRINT	CHAR(13)+CHAR(10)+'Value for @columnList4TableData = '+ISNULL(@columnList4TableData,'<<NULL>>');
	END

	SET @sqlString = N'
		SELECT CAST ( ( SELECT '+@columnList4TableData+'
					  FROM '+@tableName+'
						WHERE 1 = 1 '+ISNULL(@queryFilter,'')+'
					  FOR XML PATH(''tr''), TYPE   
			) AS NVARCHAR(MAX) )';
	IF @p_Verbose = 1
	BEGIN
		PRINT CHAR(13)+CHAR(10)+'Evaluating value for @sqlString = '+CHAR(13)+CHAR(10)+ISNULL(@sqlString,'<<NULL>>'); 
		PRINT CHAR(13)+CHAR(10)+'Now populating table @data4TableData';
	END


	INSERT @data4TableData
	EXEC (@sqlString);

	SELECT @columnList4TableData = TableData FROM @data4TableData;

	IF @p_Verbose = 1
	BEGIN
		PRINT 'Table @data4TableData has been populated using @sqlString'; 
		SELECT 'SELECT * FROM @data4TableData' AS RunningQuery, * FROM @data4TableData;
		PRINT CHAR(13)+CHAR(10)+'Value for @columnList4TableData has been reset to '+CHAR(13)+CHAR(10)+ISNULL(@columnList4TableData,'<<NULL>>');
	END

	--	If no data to share on Mail, then return
	IF NOT EXISTS (SELECT * FROM @data4TableData as d WHERE d.TableData IS NOT NULL)
	BEGIN
		IF @p_Verbose = 1
			PRINT 'No Data to share on Mail. Value of @data4TableData is null.';
		RETURN
	END

	IF @p_JobName IS NOT NULL AND @p_Option = 'JobBlockers'
		SET @subject = QUOTENAME(@p_JobName) + ' - ' + @p_Option;
	ELSE IF @subject IS NULL
		SET @subject = @p_Option;

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
	SET @htmlBody = N'<H1>'+@subject+'</H1>' +  
		N'<table border="1" class="'+@p_DefaultHTMLStyle+'">' +  
		N'<tr>'+@columnList4TableHeader+'</tr>' +  
		+@columnList4TableData+
		N'</table>' ;  

	SET @htmlBody = @htmlBody + '
<p>
<br><br>
Thanks & Regards,<br>
SQL Alerts<br>
DBA@contso.com<br>
-- Alert Coming from SQL Agent Job [DBA Log Walk Alerts]<br>
</p>
';

	IF @p_Verbose = 1
		PRINT 'Set value for @mailHTML using @cssStyle_GreenBackgroundHeader and @htmlBody values.';
	SET @mailHTML =  @cssStyle_GreenBackgroundHeader + @htmlBody;

	IF (@p_recipients IS NULL) 
	BEGIN
		SET @p_recipients = 'ajay.dwivedi@contso.com';
	END

	EXEC msdb.dbo.sp_send_dbmail 
		@recipients = @p_recipients,  
		@subject = @subject,  
		@body = @mailHTML,  
		@body_format = 'HTML' ; 
END -- Procedure

GO
