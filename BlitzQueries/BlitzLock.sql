declare @_startDate datetime;
declare @_endDate datetime;
set @_startDate = dateadd(hour,-24,getdate());
set @_endDate = GETDATE()

exec sp_BlitzLock @StartDate = @_startDate, @EndDate = @_endDate
					