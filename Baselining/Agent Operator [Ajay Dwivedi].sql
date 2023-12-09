USE [msdb]
GO
EXEC msdb.dbo.sp_add_operator @name=N'Ajay Dwivedi', 
		@enabled=1, 
		@pager_days=0, 
		@email_address=N'ajay.dwivedi@contso.com'
GO
