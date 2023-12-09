https://github.com/Microsoft/DiagManager
https://github.com/microsoft/DiagManager/wiki/Creating-Custom-Collectors
https://github.com/microsoft/DiagManager/wiki/Creating-PSSDiag-Package
https://github.com/microsoft/DiagManager/wiki/Running-PSSDiag
https://github.com/microsoft/DiagManager/wiki/Running-PSSDiag-on-a-Cluster
https://databasebestpractices.com/detailed-overview-pssdiag/

https://www.sqldbadiaries.com/2010/09/12/run-pssdiag-through-a-sql-agent-job/
https://itknowledgeexchange.techtarget.com/sql-server/pssdiag-has-some-useful-parameters/

-- Create service <<SQLDIAG>>
pssdiag.cmd /R

-- Start service
net start sqldiag

-- Stop service
net stop sqldiag

SET NOCOUNT ON;
DECLARE @output_table table (ID int identity(1,1), output varchar(500) null);
DECLARE @result int;  

INSERT @output_table
EXEC @result = xp_cmdshell 'net stop sqldiag';

-- SELECT * FROM @output_table o where o.output like '%The SQLDIAG service is not started%'

IF (@result = 0 OR EXISTS (SELECT * FROM @output_table o where o.output like '%The SQLDIAG service is not started%')) 
   PRINT 'SQLDIAG not running'  
ELSE  
   PRINT 'Failure'; 
