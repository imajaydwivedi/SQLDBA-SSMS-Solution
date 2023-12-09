Logman create counter msperf -f bin -c  "\SQLServer:Buffer Manager\*" "\SQLServer:Memory Node(*)\*" "\SQLServer:Buffer Node(*)\*" "\SQLServer:Locks(*)\*" "\SQLServer:Databases(*)\*" "\SQLServer:Database Mirroring(*)\*" "\SQLServer:General Statistics\*" "\SQLServer:Latches\*" "\SQLServer:Access Methods\*" "\SQLServer:SQL Statistics\*" "\SQLServer:Memory Manager\*" "\SQLServer:Wait Statistics(*)\*" "\LogicalDisk(*)\*" "\PhysicalDisk(*)\*" "\Processor(*)\*" "\Process(*)\*" "\Memory\*" "\System\*" -si 00:00:01 -o G:\PerfMonLogs_2018Sep21\MS_perf_log.blg -cnf 24:00:00 -max 500

ComputerName : MyDbServerName
InstanceName : MSSQLSERVER
SqlInstance  : MyDbServerName
SqlMaxMB     : 250000
TotalMB      : 294878

select 294878/1024 as total, 250000/1024 as maxmemory