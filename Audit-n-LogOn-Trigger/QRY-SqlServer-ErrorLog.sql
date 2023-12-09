declare @start_time smalldatetime = dateadd(minute,-10,convert(smalldatetime,getdate()));
--select [@start_time] = @start_time;

exec xp_readerrorlog 0,1,null,null,@start_time,null,'desc';