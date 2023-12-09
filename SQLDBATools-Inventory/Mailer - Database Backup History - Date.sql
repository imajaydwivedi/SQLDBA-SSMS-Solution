--	Mailer - Database Backup History - <Date>
DECLARE @tableHTML  NVARCHAR(MAX) ;
DECLARE @subject VARCHAR(200);

SET @subject = 'Database Backup History - '+CAST(CAST(GETDATE() AS DATE) AS VARCHAR(20));
--SELECT @subject

SET @tableHTML =  N'
<style>
#BackupHistory {
    font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
    border-collapse: collapse;
    width: 100%;
}

#BackupHistory td, #BackupHistory th {
    border: 1px solid #ddd;
    padding: 8px;
}

#BackupHistory tr:nth-child(even){background-color: #f2f2f2;}

#BackupHistory tr:hover {background-color: #ddd;}

#BackupHistory th {
    padding-top: 12px;
    padding-bottom: 12px;
    text-align: left;
    background-color: #4CAF50;
    color: white;
}
</style>'+
    N'<H1>'+@subject+'</H1>' +  
    N'<table border="1" id="BackupHistory">' +  
    N'<tr>
	<th>ServerInstance</th>' + 
		N'<th>DatabaseName</th>' +  
		N'<th>DatabaseCreationDate</th>'+
		N'<th>RecoveryModel</th>'+
		N'<th>HasFullBackup<br>InLast24Hours</th>' +  
		N'<th>LastFullBackupDate</th>'+
		N'<th>LastDifferential<br>BackupDate</th>' +  
		N'<th>LastLogBackupDate</th>'+
		N'<th>CollectionTime</th>
	</tr>' +  
    CAST ( ( SELECT td = ServerInstance, '',  
                    td = DatabaseName, '',  
                    td = DatabaseCreationDate, '',  
                    td = RecoveryModel, '',  
                    td = IsFullBackupInLast24Hours, '',  
					td = ISNULL(CAST(LastFullBackupDate AS varchar(100)),' '), '', 
					td = ISNULL(CAST(LastDifferentialBackupDate AS varchar(100)),' '), '', 
					td = ISNULL(CAST(LastLogBackupDate AS varchar(100)),' '), '',
                    td = CollectionTime  
              FROM dbo.vw_DatabaseBackups as b
				WHERE b.IsFullBackupInLast24Hours = 'No'  
              FOR XML PATH('tr'), TYPE   
    ) AS NVARCHAR(MAX) ) +  
    N'</table>' ;  

EXEC msdb.dbo.sp_send_dbmail 
	@recipients='ajay.dwivedi@contso.com;Anant.Dwivedi@contso.com',  
    @subject = @subject,  
    @body = @tableHTML,  
    @body_format = 'HTML' ; 
