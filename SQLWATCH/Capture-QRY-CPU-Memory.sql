use DBA;

select top 3 getdate(), * from DBA..dm_os_performance_counters order by collection_time desc
select top 3 getdate(), * from DBA..dm_os_process_memory order by collection_time desc
select top 3 getdate(), * from DBA..dm_os_sys_memory order by collection_time desc
select top 3 getdate(), * from DBA..dm_os_ring_buffers order by collection_time desc

--exec ('waitfor delay ''00:00:05''')