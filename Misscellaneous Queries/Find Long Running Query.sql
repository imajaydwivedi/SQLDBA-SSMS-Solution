use tempdb
go

DBCC SQLPERF(LOGSPACE)
GO
/*
328304.1	98.5502
*/

DBCC OPENTRAN
/*
Transaction information for database 'tempdb'.

Oldest active transaction:
    SPID (server process ID): 458
    UID (user ID) : -1
    Name          : sort_init
    LSN           : (1076280:11404:464)
    Start time    : Mar 26 2018  3:32:18:520AM
    SID           : 0x01050000000000051500000074380f7e9534a32ef375d6516a870400
DBCC execution completed. If DBCC printed error messages, contact your system administrator.
*/

DBCC INPUTBUFFER(458)
/*
exec usp_ImportTriplets 
*/

exec sp_whoIsActive
