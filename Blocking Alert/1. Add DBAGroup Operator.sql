USE [msdb]
GO

/****** Object:  Operator [DBAGroup]    Script Date: 8/9/2018 9:40:47 AM ******/
EXEC msdb.dbo.sp_add_operator @name=N'DBAGroup', 
		@enabled=1, 
		@weekday_pager_start_time=90000, 
		@weekday_pager_end_time=180000, 
		@saturday_pager_start_time=90000, 
		@saturday_pager_end_time=180000, 
		@sunday_pager_start_time=90000, 
		@sunday_pager_end_time=180000, 
		@pager_days=0, 
		@email_address=N'sqlagentservice@gmail.com', 
		@category_name=N'[Uncategorized]'
GO


