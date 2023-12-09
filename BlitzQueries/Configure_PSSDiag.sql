Instructions to run PSSDIAG:

IMPORTANT Questions
Where to run this TOOL?
This Tool needs to be run on the SQL server Database server where you are having issue/performance issue.
 
Who can run this TOOL?
----------------------
Anyone with the Windows admin account and SQL sysadmin permission on that account.            
Example : if we have a domain login �MYDOMAISQLDBAIN� this account should be admin at windows level as well as SQL level.

When can you run the TOOL?
-------------------------
If you are able to reproduce the issue then, 1- START the PSSDIAG , 2-Repro the issue 3-STOP the PSSDIAG after finishing the repro 4- send data.
In your case it is perf issue so confirm from the app team if they are facing perf issue  or ask them to intimate you when the issue happens
When you get the intimation start the tool and run for 20-25 min and make sure that the issue was present during the time the Tool was running.
 
How to run the TOOL?
---------------------
See below instruction.
 
PSSDIAG instructions:
How to capture the diagnostic info I requested using PSSDIAG: 
 
PSSDIAG must be executed locally at SQL Server on the ACTIVE NODE
 
1.             Create a folder named PSSDIAG on your SQL server machine. This folder should be on a drive with plenty of space as diagnostic file collections can be quite large. Also avoid a disk where databases or tlogs are present.
2.             Download pssd.exe from the workspace and save to the PSSDIAG folder. 
3.             Open a command prompt under administrator credentials, this account MUST BE part of Local Administrators and also SQL Administrator. Change the current directory to your PSSDIAG folder and run pssd.exe to extract its contents. 
4.             Stop all other profiler traces that may be running on the server, as well as any perfmon monitoring tool 
5.             Run PSSDIAG.CMD at the command prompt to start the collection process. 
6.             Once PSSDIAG displays the message, �Collection started,� attempt to reproduce your issue. 
7.             Stop PSSDIAG by pressing CTRL+C once. Wait for the collector to shutdown 
                                Do not stop the batch file, let the batch file to complete. If questioned to stop the batch file answer �N� 
8.             Compact and upload the contents of the output folder 
9.             Use the file transfer area below for upload
  
Notes: 
�              Do not run unexpected REINDEX, Backups or any other operation that may skew the regular server operation. 
�              Do not have other SQL profiler traces running concurrently with PSSDIAG 
�              Do not have perfmon or other Windows performance counters collection tools started, as this may cause PSSDIAG not to collect perfmon counters 
�              This pssdiag may have been configured with an option to recycle profiler trace (.trc) and perfmon (.blg) files. You should monitor how long it takes for the output folder to create 50 of these files as this is your time window to stop pssdiag and avoid losing data after the issue reproduces

