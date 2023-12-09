use tempdb
go
dbcc opentran
go

select * 
from DBA..whoIsActive_resultsets r
where r.collection_time = (select max(ri.collection_time) from DBA..whoIsActive_resultsets ri)
go
