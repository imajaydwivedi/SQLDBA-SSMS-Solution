HOW TO ENABLE AGENT LOGGING

1.Click Open on the Publishers node.
2.Click the publisher that has the publication that has the problem.
3.Click Publication.
4.In the right-hand pane of SQL Server Management Studio is a list of the agents related to the publication. You see the Snapshot Agent, Log Reader Agent and the Push/Pull Subscription Agent.
5.Identify the agent for which you need to set up output logging.
6.Right-click the replication agent you identified in step 6, and then click Agent Properties.
7.Click the Steps tab, and then edit the Run Agent step.
8.At the end of the string under command, add:

-Output C:\Temp\OUTPUTFILE.txt -Outputverboselevel [0|1|2]


Specify either 0, 1, or 2 after the -Outputverboselevel parameter.
9.Click OK to save the changes, and then close the Edit Job Step dialog box.
10.Click OK to save the changes, and then close the Replication Agent Properties dialog box. If the agent is set to run continuously, stop and restart the replication agent so that SQL Server logs the messages to the log file specified in step 9. If the file already exists, the agent appends the output to the file.
