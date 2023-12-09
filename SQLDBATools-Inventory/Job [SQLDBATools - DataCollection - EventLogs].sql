DECLARE @result varchar(255);
DECLARE @_errorMSG VARCHAR(500);  

EXEC @result = xp_cmdshell 'PowerShell.exe -noprofile -command "C:\Program` Files\WindowsPowerShell\Modules\SQLDBATools\Cmdlets\Wrapper-EventLogs.ps1"' ,no_output;  

IF (@result = '0') 
BEGIN 
	PRINT 'PowerShell script successfully executed.';
	EXEC SQLDBATools..[usp_GetMail_4_SQLDBATools] @p_Option = 'EventLogs' ,@p_recipients = 'SQLDBA@contso.com';--SQLDBA@contso.com	
END
ELSE
BEGIN
	SET @_errorMSG = @result;
	IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
		EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
	ELSE
		EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
END
