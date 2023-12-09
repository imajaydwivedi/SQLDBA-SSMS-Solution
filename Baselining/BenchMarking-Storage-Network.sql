--	How to Check Performance on a New SQL Server
https://www.brentozar.com/archive/2018/08/how-to-check-performance-on-a-new-sql-server/

--	Free SQL Server Load Testing Tools
https://www.brentozar.com/archive/2019/04/free-sql-server-load-testing-tools/

--	Simulating Production Workloads with SQL Server Distributed Replay
https://app.pluralsight.com/library/courses/sql-server-distributed-replay/table-of-contents

--	How to Use CrystalDiskMark 7 to Test Your SQL Server’s Storage
https://sqlperformance.com/2015/05/io-subsystem/analyzing-io-performance-for-sql-server
https://sqlperformance.com/2015/08/io-subsystem/diskspd-test-storage
https://www.brentozar.com/archive/2019/11/how-to-use-crystaldiskmark-7-to-test-your-sql-servers-storage/
https://www.overclock.net/forum/20-hard-drives-storage/1231707-can-someone-explain-different-crystaldiskmark-tests.html
https://www.thegeekdiary.com/what-is-hba-queue-depth-and-how-to-check-the-current-queue-depth-value-and-how-to-change-it/

diskspd.exe -b8K -d30 -o4 -t8 -h -r -w25 -L -Z1G -c20G F:\DBA\iotest.dat > DiskSpeedResults.txt
diskspd.exe -d15 -o4 -t4 -b8k -r -L -w50  -c1G testdiskspd

--	Network Load Testing Using iPerf
https://sqlperformance.com/2015/12/monitoring/network-testing-iperf

	Setup on Test Server
	--------------------
	G:\DBA\iperf-3.1.3-win64

	On Server =>
	iperf3 -s

	On Client => 
	iperf3 -c YourServerName -t 120 -P 50
	-- 120 seconds, 30 threads

		-- Method 01: Powershell
	& "C:\iperf-3.1.3-win64\iperf3.exe" -c YourServerName -t 120 -P 50
	& "C:\iperf-3.1.3-win64\iperf3.exe" -s

		-- Method 02: Powershell
	cmd.exe /c "C:\iperf-3.1.3-win64\iperf3.exe -s"
	cmd.exe /c "C:\iperf-3.1.3-win64\iperf3.exe -c YourServerName -t 120 -P 50"