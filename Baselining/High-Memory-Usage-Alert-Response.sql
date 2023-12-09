Hi @User,

There are variety of components within SQL Server itself that take memory, and are not accounted in Max Memory Setting.

Below are 2 blog posts by MCM/MVP Jonathan Kehayias that explain the same in much better word than we can do.

https://www.sqlskills.com/blogs/jonathan/how-much-memory-does-my-sql-server-actually-need/
https://www.sqlskills.com/blogs/jonathan/wow-an-online-calculator-to-misconfigure-your-sql-server-memory/

Based on Jonathan’s recommendations, SQL Server experts(MVPs) have created powershell cmdlet Set-DbaMaxMemory/Test-DbaMaxMemory as part of DBATools module. We use this cmdlet to verify the memory/DOP settings.

Kindly let me know in case of any query.
