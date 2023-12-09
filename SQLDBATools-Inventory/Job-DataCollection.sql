DECLARE @result int;
DECLARE @_errorMSG VARCHAR(500);  

EXEC @result = xp_cmdshell 'PowerShell.exe -noprofile -command "C:\Users\adwivedi\Documents\WindowsPowerShell\Modules\SQLDBATools\Cmdlets\Wrapper-DatabaseBackupInfo.ps1"' ,no_output;  
EXEC [SQLDBATools].Staging.usp_ETL_DatabaseBackup;
EXEC SQLDBATools..[usp_GetMail_4_SQLDBATools] @p_Option = 'BackupInfo' ,@p_recipients = 'ajay.dwivedi@contso.com;Anant.Dwivedi@contso.com'; 

IF (@result = 0) 
BEGIN 
	PRINT 'PowerShell script successfully executed.';	
END
ELSE
BEGIN
	SET @_errorMSG = 'PowerShell script execution has failed.';
	IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
		EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
	ELSE
		EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
END
