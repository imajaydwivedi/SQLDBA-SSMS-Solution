bcp  "exec DBA.dbo.WhoIsActive_ResultSets" queryout "G:\Performance-Issues\MyDbServerName\WhoIsActive_ResultSets.txt" -w -C OEM -t"," -T -SMyDbServerName

BCP "select * from DBA.[dbo].[commandlog_stage_testing_TestCase01]" queryout "D:\commandlog_stage_testing_TestCase01.dat" -S MSI -T -c -t"!~!"

BCP [$database].dbo.commandlog_stage_testing_TestCase01 in "D:\commandlog_stage_testing_TestCase01.dat" -S msi -T -c -t"!~!"