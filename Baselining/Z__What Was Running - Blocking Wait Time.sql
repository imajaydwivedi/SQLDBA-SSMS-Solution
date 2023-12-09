DECLARE @p_wait_info varchar(2000)
--SET @p_wait_info = '(1x: 53956ms)LCK_M_S, (8x: 34449/34449/34451ms)CXPACKET:6, (1x: 661622ms)CXPACKET:2'
SET @p_wait_info = '(12ms)LCK_M_RS_U'

select	--lock_text
		[WaitTime(Seconds)] = CASE WHEN CHARINDEX(':',lock_text) = 0
									THEN CAST(SUBSTRING(lock_text, CHARINDEX('(',lock_text)+1, CHARINDEX('ms',lock_text)-(CHARINDEX('(',lock_text)+1)) AS BIGINT)/1000
									ELSE CAST(SUBSTRING(lock_text, CHARINDEX(':',lock_text)+1, CHARINDEX('ms',lock_text)-(CHARINDEX(':',lock_text)+1)) AS BIGINT)/1000
									END
from (
				SELECT	[lock_text] = CASE	WHEN @p_wait_info IS NULL OR CHARINDEX('LCK',@p_wait_info) = 0
											THEN NULL
											WHEN CHARINDEX(',',@p_wait_info) = 0
											THEN @p_wait_info
											WHEN CHARINDEX(',',LEFT(@p_wait_info,  CHARINDEX(',',@p_wait_info,CHARINDEX('LCK_',@p_wait_info))-1   )) <> 0
											THEN REVERSE(LEFT(	REVERSE(LEFT(@p_wait_info,  CHARINDEX(',',@p_wait_info,CHARINDEX('LCK_',@p_wait_info))-1)),
															CHARINDEX(',',REVERSE(LEFT(@p_wait_info,  CHARINDEX(',',@p_wait_info,CHARINDEX('LCK_',@p_wait_info))-1)))-1
														))
											ELSE LEFT(@p_wait_info,  CHARINDEX(',',@p_wait_info,CHARINDEX('LCK_',@p_wait_info))-1   )
											END
			) as wi
