select t.LogId as t_LogId, o.LogId as o_LogId, [% remaining] = convert(numeric(20,2),((o.LogId-t.LogId)*100.0)/o.LogId)
from (select top 1 LogId from [dbo].[User_Posts_old] with (nolock) order by LogId desc) t,
	(select top 1 LogId from [dbo].[User_Posts] with (nolock) order by LogId desc) o
go

select top 1 LogId from [dbo].[User_Posts_Ajay] with (nolock) order by LogId desc
select top 1 LogId from [dbo].[User_Posts] with (nolock) order by LogId desc
go

DECLARE @batchSize INT
DECLARE @results INT
declare @LogId_counter bigint;
declare @sql nvarchar(max);
declare @LogId_start bigint;
declare @LogId_end bigint;
declare @loop_counter int = 1;

select @LogId_start = min(LogId), @LogId_end = max(LogId) from [dbo].[User_Posts] o;
select @LogId_start, @LogId_end;

SET @results = 1 --stores the row count after each successful batch
SET @batchSize = 10000 --How many rows you want to operate on each batch
set @LogId_counter = @LogId_start

--truncate table StackOverflow.[dbo].[User_Posts_Ajay]

set @sql = '
SELECT LogDate, ClientCode, ClientName, Age, EmailId, MobileNo, Gender, ProbabilityParameter, B2bOrB2c, CvlKraVerifiedFlag, MarginFundAddedFlag, FnOActiveFlag, FundValue, WHATSAPPONBOARD, FOACT10FREE, ITRADE, FREE_STOCK, WHATSAPPSB, FOCOMMODITY, FOACT, PROFITLOSS, FA1TF, FA4TF, WHATSAPP, FOFIFTY, FOCURRENCY, OnBoardingDate, TradingDay, TradeWin, DIY, REF_EARN, REF_EARN_CODE, REF_EARN_CNT, FA4TF_WA, FREE_ETF, PushedFrom, TradingDay1, TradingDay2, TradingDay3, TradingDay_Flag, IsTraded_Flag, control_flag, Profiling, Voucher_Plan, LogId, Cust_Support, CouponCode, ARQ_REF_EARN_CODE, EncryptedCltcd, B2bOrB2c_Current, control_flag2, BranchCode
   FROM [dbo].[User_Posts] o with (index ([LogId]))
   WHERE o.LogId >= @LogId_counter and o.LogId < (@LogId_counter + @batchSize);'

-- when 0 rows returned, exit the loop
SET IDENTITY_INSERT StackOverflow.[dbo].[User_Posts_Ajay] ON;
WHILE (@LogId_counter <= @LogId_end) 
BEGIN
   
	print 'Insert data from '+cast(@LogId_counter as varchar(20));

   INSERT StackOverflow.[dbo].[User_Posts_Ajay] WITH (TABLOCK)
   (LogDate, ClientCode, ClientName, Age, EmailId, MobileNo, Gender, ProbabilityParameter, B2bOrB2c, CvlKraVerifiedFlag, MarginFundAddedFlag, FnOActiveFlag, FundValue, WHATSAPPONBOARD, FOACT10FREE, ITRADE, FREE_STOCK, WHATSAPPSB, FOCOMMODITY, FOACT, PROFITLOSS, FA1TF, FA4TF, WHATSAPP, FOFIFTY, FOCURRENCY, OnBoardingDate, TradingDay, TradeWin, DIY, REF_EARN, REF_EARN_CODE, REF_EARN_CNT, FA4TF_WA, FREE_ETF, PushedFrom, TradingDay1, TradingDay2, TradingDay3, TradingDay_Flag, IsTraded_Flag, control_flag, Profiling, Voucher_Plan, LogId, Cust_Support, CouponCode, ARQ_REF_EARN_CODE, EncryptedCltcd, B2bOrB2c_Current, control_flag2, BranchCode)   
   exec sp_ExecuteSql @sql, N'@LogId_counter bigint, @batchSize int', @LogId_counter = @LogId_counter, @batchSize = @batchSize;
   --order by LogId;

   -- very important to obtain the latest rowcount to avoid infinite loops
   SET @results = @@ROWCOUNT

   -- next batch
   SET @LogId_counter = @LogId_counter + @batchSize;
   
   set @loop_counter += 1;
 --  if(@loop_counter > 2)
	--break;
END
SET IDENTITY_INSERT StackOverflow.[dbo].[User_Posts_Ajay] OFF;
go

/*
exec sp_rename 'dbo.User_Posts','User_Posts_old';
go
select 'INSERT the DELTA data'
go
exec sp_rename 'dbo.User_Posts_Ajay','User_Posts';
go
*/

--create index LogId on [StackOverflow].[dbo].[User_Posts] (LogId) with (maxdop = 0);
--go

