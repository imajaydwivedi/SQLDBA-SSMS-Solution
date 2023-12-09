# Debugging SQL Server using Windows Debugger

## Setup Windows Debugger
### https://www.youtube.com/watch?v=h6tCva6oHio&ab_channel=SQLMaestros
### https://www.youtube.com/watch?v=eVy962D0Tko&ab_channel=DataPlatformGeeks%26SQLServerGeeks
### https://learn.microsoft.com/en-us/windows/win32/dxtecharts/debugging-with-symbols?redirectedfrom=MSDN
### https://stackoverflow.com/questions/4946685/good-tutorial-for-windbg
### https://www.brentozar.com/archive/2018/03/so-you-wanna-debug-sql-server-part-1/


1. Download Windows SDK
   - Check supported OS. Download ISO.
   - Install Only Debugger Components. None other is required.
2. Download public symbols into C:\symbols
   1. Symbol File Path
      - srv*c:\symbols*https://msdl.microsoft.com/download/symbols
   2. Download symbols for all DLLs of SQLServer Instance
      - Navigate to Binn path of sql instance. For example, C:\Program Files\Microsoft SQL Server\\MSSQL15.MSSQLSERVER\\MSSQL\Binn
      - In elevated cmd, run following command
        - "C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\symchk.exe" *.dll /s srv*c:\symbols*https://msdl.microsoft.com/download/symbols
3. Attach SQLServr process

## 
