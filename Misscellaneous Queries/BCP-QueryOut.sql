bcp  "exec DBA.dbo.WhoIsActive_ResultSets" queryout "G:\Performance-Issues\MyDbServerName\WhoIsActive_ResultSets.txt" -w -C OEM -t"," -T -SMyDbServerName

BCP "select * from dbo.vw_performance_counters pc where pc.collection_time_utc between dateadd(day,-16,getutcdate()) and dateadd(day,-1,getutcdate())" `
        queryout "T:\DBA_Network_Test_Using_BCP.dat" -S SqlPractice -d DBA -a 65535 -T -c -t"!~!"
-- 4.35 gb completed in 172 seconds

BCP [$database].dbo.commandlog_stage_testing_TestCase01 in "D:\commandlog_stage_testing_TestCase01.dat" -S msi -T -c -t"!~!"