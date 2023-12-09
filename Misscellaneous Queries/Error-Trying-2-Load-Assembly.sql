Msg 10314, Level 16, State 11, Line 3
An error occurred in the Microsoft .NET Framework while trying to load assembly id 65551. The server may be running out of resources, or the assembly may not be trusted with PERMISSION_SET = EXTERNAL_ACCESS or UNSAFE. Run the query again, or check documentation to see how to solve the assembly trust issues. For more information about this error: 
System.IO.FileLoadException: Could not load file or assembly 'DBA.vesta.extendedprocedures, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null' or one of its dependencies. Exception from HRESULT: 0x80FC80F1


For assemblies to work properly, below things should be in order:-

dbowner - sa
TRUSTWORTHY - ON
clr - enabled
Assembly permission set = unsafe(unrestricted)

In order to resolve the same, I have to rodify the DBA Log Walk stored procedure DBA..usp_DBARestoreBkup on DS15