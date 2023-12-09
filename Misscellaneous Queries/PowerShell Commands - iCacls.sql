
1) Permission Issues
-- For folders, use:
takeown --% /f "C:\Program Files\Microsoft SQL Server" /r /d y /a
icacls --% "C:\Program Files\Microsoft SQL Server" /grant "contso\devsql":F /t /q

-- For Files
takeown /f file_name /d y
icacls file_name /grant username_or_usergroup:F /q
