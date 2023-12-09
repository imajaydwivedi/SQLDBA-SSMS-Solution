exec sp_configure 'show advanced options', 1 ;  
GO  
RECONFIGURE ;  
GO  
exec sp_configure 'blocked process threshold', 15 ; -- set to 300 seconds or more
GO  
RECONFIGURE ;  
GO