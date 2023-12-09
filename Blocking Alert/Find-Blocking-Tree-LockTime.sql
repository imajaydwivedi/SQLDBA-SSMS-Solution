;WITH T_BLOCKERS AS
(
	-- Find block Leaders
	SELECT	[collection_time], [TimeInMinutes], [session_id], 
			[sql_text] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(COALESCE([sql_command],[sql_text]) AS VARCHAR(MAX)),char(13),''),CHAR(10),''),'<?query --',''),'--?>',''), 
			[login_name], [wait_info], [blocking_session_id], [blocked_session_count], [locks], 
			[status], [tran_start_time], [open_tran_count], [host_name], [database_name], [program_name], additional_info,
			r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[reads], r.[writes], r.[physical_io], r.[physical_reads], --r.[query_plan],
			[LEVEL] = CAST (REPLICATE ('0', 4-LEN (CAST (r.session_id AS VARCHAR))) + CAST (r.session_id AS VARCHAR) AS VARCHAR (1000))
	FROM	[DBA].[dbo].WhoIsActive_ResultSets AS r
	WHERE	r.collection_Time >= 'Apr 30 2019  00:00AM' AND r.collection_Time <= 'May 01 2019  00:00AM' 
		AND	(ISNULL(r.blocking_session_id,0) = 0 OR ISNULL(r.blocking_session_id,0) = r.session_id)
		AND EXISTS (SELECT * FROM [DBA].[dbo].WhoIsActive_ResultSets AS R2 WHERE R2.collection_Time = r.collection_Time AND ISNULL(R2.blocking_session_id,0) = r.session_id AND ISNULL(R2.blocking_session_id,0) <> R2.session_id)
	--	
	UNION ALL
	--
	SELECT	r.[collection_time], r.[TimeInMinutes], r.[session_id], 
			[sql_text] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(COALESCE(r.[sql_command],r.[sql_text]) AS VARCHAR(MAX)),char(13),''),CHAR(10),''),'<?query --',''),'--?>',''), 
			r.[login_name], r.[wait_info], r.[blocking_session_id], r.[blocked_session_count], r.[locks], 
			r.[status], r.[tran_start_time], r.[open_tran_count], r.[host_name], r.[database_name], r.[program_name], r.additional_info,
			r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[reads], r.[writes], r.[physical_io], r.[physical_reads], --r.[query_plan],
			CAST (B.LEVEL + RIGHT (CAST ((1000 + r.session_id) AS VARCHAR (100)), 4) AS VARCHAR (1000)) AS LEVEL
	FROM	[DBA].[dbo].WhoIsActive_ResultSets AS r
	INNER JOIN 
			T_BLOCKERS AS B
		ON	r.collection_time = B.collection_time
		AND	r.blocking_session_id = B.session_id
	WHERE	r.blocking_session_id <> r.session_id
)
--select * from T_BLOCKERS
	
SELECT	[collection_time], 
		[BLOCKING_TREE] = N'    ' + REPLICATE (N'|         ', LEN (LEVEL)/4 - 1) 
						+	CASE	WHEN (LEN(LEVEL)/4 - 1) = 0
									THEN 'HEAD -  '
									ELSE '|------  ' 
							END
						+	CAST (r.session_id AS NVARCHAR (10)) + N' ' + (CASE WHEN LEFT(r.[sql_text],1) = '(' THEN SUBSTRING(r.[sql_text],CHARINDEX('exec',r.[sql_text]),LEN(r.[sql_text]))  ELSE r.[sql_text] END),
		[session_id], [blocking_session_id], 
		--w.lock_text,
		[WaitTime(Seconds)] = COALESCE([lock_time(UnExpected)], [lock_time(1)],[lock_time(2)],[lock_time(x)])/1000,
		[sql_commad] = CONVERT(XML, '<?query -- '+char(13)
						+ (CASE WHEN LEFT([sql_text],1) = '(' THEN SUBSTRING([sql_text],CHARINDEX('exec',[sql_text]),LEN([sql_text]))  ELSE [sql_text] END)
						+ char(13)+'--?>'), 
		[host_name], [database_name], [login_name], [program_name],	[wait_info], [blocked_session_count], [locks], [tran_start_time], [open_tran_count], additional_info
		,r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[reads], r.[writes], r.[physical_io], r.[physical_reads] --, r.[query_plan]
FROM	T_BLOCKERS AS r
OUTER APPLY
	(	
		select	lock_text,								
				[lock_time(UnExpected)] = CASE WHEN lock_text IS NULL THEN NULL -- When Lock_Test is NULL or Not Valid
										WHEN lock_text IS NOT NULL AND CHARINDEX(':',lock_text) = 0
										THEN CAST(SUBSTRING(lock_text,2,CHARINDEX('ms)',lock_text)-2) AS bigint)
										ELSE NULL		
										END
				,[lock_time(1)] = CASE WHEN lock_text IS NOT NULL AND CHARINDEX(':',lock_text) <> 0
										THEN CASE	WHEN CAST(SUBSTRING(lock_text,2,CHARINDEX('x:',lock_text)-2) AS INT) = 1
													THEN CAST(SUBSTRING(lock_text,6,CHARINDEX('ms)',lock_text)-6) AS bigint)
													ELSE NULL
													END
										ELSE NULL		
										END
				,[lock_time(2)] = CASE WHEN lock_text IS NOT NULL AND CHARINDEX(':',lock_text) <> 0
										THEN CASE	WHEN CAST(SUBSTRING(lock_text,2,CHARINDEX('x:',lock_text)-2) AS INT) = 2
													THEN CAST(SUBSTRING(lock_text,CHARINDEX('/',lock_text)+1,CHARINDEX('ms)',lock_text)-CHARINDEX('/',lock_text)-1) AS bigint)
													ELSE NULL
													END
										ELSE NULL		
										END
				,[lock_time(x)] = CASE WHEN lock_text IS NOT NULL AND CHARINDEX(':',lock_text) <> 0
										THEN CASE	WHEN CAST(SUBSTRING(lock_text,2,CHARINDEX('x:',lock_text)-2) AS INT) > 2
													THEN CAST(SUBSTRING(lock_text, CHARINDEX('/',lock_text,CHARINDEX('/',lock_text)+1)+1, CHARINDEX('ms)',lock_text)-CHARINDEX('/',lock_text,CHARINDEX('/',lock_text)+1)-1) AS bigint)
													ELSE NULL
													END
										ELSE NULL		
										END

				,[WaitTime(Seconds)] =
						CASE WHEN CHARINDEX(':',lock_text) = 0
								THEN CAST(SUBSTRING(lock_text, CHARINDEX('(',lock_text)+1, CHARINDEX('ms',lock_text)-(CHARINDEX('(',lock_text)+1)) AS BIGINT)/1000
								ELSE CAST(SUBSTRING(lock_text, CHARINDEX(':',lock_text)+1, CHARINDEX('ms',lock_text)-(CHARINDEX(':',lock_text)+1)) AS BIGINT)/1000
								END
								
		from (
			SELECT	[lock_text] = CASE	WHEN r.[wait_info] IS NULL OR CHARINDEX('LCK',r.[wait_info]) = 0
										THEN NULL
										WHEN CHARINDEX(',',r.[wait_info]) = 0
										THEN r.[wait_info]
										WHEN CHARINDEX(',',LEFT(r.[wait_info],  CHARINDEX(',',r.[wait_info],CHARINDEX('LCK_',r.[wait_info]))-1   )) <> 0
										THEN REVERSE(LEFT(	REVERSE(LEFT(r.[wait_info],  CHARINDEX(',',r.[wait_info],CHARINDEX('LCK_',r.[wait_info]))-1)),
														CHARINDEX(',',REVERSE(LEFT(r.[wait_info],  CHARINDEX(',',r.[wait_info],CHARINDEX('LCK_',r.[wait_info]))-1)))-1
													))
										ELSE LEFT(r.[wait_info],  CHARINDEX(',',r.[wait_info],CHARINDEX('LCK_',r.[wait_info]))-1   )
										END
		) as wi
	) AS w
ORDER BY collection_time, LEVEL ASC;

/*
select			lock_text,
				[lock_text(UnExpected)] = CASE WHEN lock_text IS NULL THEN NULL -- When Lock_Test is NULL or Not Valid
										WHEN lock_text IS NOT NULL AND CHARINDEX(':',lock_text) = 0
										THEN SUBSTRING(lock_text,2,CHARINDEX('ms)',lock_text)-2)
										ELSE NULL		
										END
				,[lock_text(1)] = CASE WHEN lock_text IS NOT NULL AND CHARINDEX(':',lock_text) <> 0
										THEN CASE	WHEN CAST(SUBSTRING(lock_text,2,CHARINDEX('x:',lock_text)-2) AS INT) = 1
													THEN SUBSTRING(lock_text,6,CHARINDEX('ms)',lock_text)-6)
													ELSE NULL
													END
										ELSE NULL		
										END
				,[lock_text(2)] = CASE WHEN lock_text IS NOT NULL AND CHARINDEX(':',lock_text) <> 0
										THEN CASE	WHEN CAST(SUBSTRING(lock_text,2,CHARINDEX('x:',lock_text)-2) AS INT) = 2
													THEN SUBSTRING(lock_text,CHARINDEX('/',lock_text)+1,CHARINDEX('ms)',lock_text)-CHARINDEX('/',lock_text)-1)
														--CASE	WHEN CAST(SUBSTRING(lock_text,CHARINDEX('/',lock_text)+1,CHARINDEX('ms)',lock_text)-CHARINDEX('/',lock_text)-1) AS INT) >= 
														--			 CAST(SUBSTRING(lock_text,6,CHARINDEX('/',lock_text)-6) AS INT)
														--		THEN CAST(SUBSTRING(lock_text,CHARINDEX('/',lock_text)+1,CHARINDEX('ms)',lock_text)-CHARINDEX('/',lock_text)-1) AS INT)
														--		ELSE CAST(SUBSTRING(lock_text,6,CHARINDEX('/',lock_text)-6) AS INT)
														--		END
													ELSE NULL
													END
										ELSE NULL		
										END
				,[lock_text(x)] = CASE WHEN lock_text IS NOT NULL AND CHARINDEX(':',lock_text) <> 0
										THEN CASE	WHEN CAST(SUBSTRING(lock_text,2,CHARINDEX('x:',lock_text)-2) AS INT) > 2
													--THEN SUBSTRING(lock_text,CHARINDEX('x:',lock_text)+3,CHARINDEX('/',lock_text)-CHARINDEX(' ',lock_text)-1)
													THEN SUBSTRING(lock_text, CHARINDEX('/',lock_text,CHARINDEX('/',lock_text)+1)+1, CHARINDEX('ms)',lock_text)-CHARINDEX('/',lock_text,CHARINDEX('/',lock_text)+1)-1)
													ELSE NULL
													END
										ELSE NULL		
										END

from (values ('(8x: 268671/268733/268892ms)LCK_M_S'),
			('(1x: 117888ms)LCK_M_IX'),
			('(2x: 162762/164363ms)LCK_M_S'),
			('(591ms)LCK_M_U'),
			(NULL)
	) as LCK_Table(lock_text)
*/