takeown /f “c:\program files\microsoft sql server” /a /r 

(/a is for ‘administratrators’; /r is for recurse)

icacls "microsoft sql server" /t /grant administrators:f

(/t is for recurse; :f is for full control)
