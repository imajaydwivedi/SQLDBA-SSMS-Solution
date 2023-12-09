USE DBA
GO

IF NOT EXISTS(SELECT * FROM sys.indexes WHERE name='NCI_WhoIsActive_ResultSets__blocking_session_id' AND object_id = OBJECT_ID('dbo.WhoIsActive_ResultSets'))
	CREATE NONCLUSTERED INDEX [NCI_WhoIsActive_ResultSets__blocking_session_id]
		ON [dbo].[WhoIsActive_ResultSets] ([blocking_session_id]) INCLUDE ([session_id],[collection_time],[program_name],[TimeInMinutes])
GO

IF OBJECT_ID('dbo.usp_WhoIsActive_Blocking') IS NULL
	EXEC('CREATE PROCEDURE dbo.usp_WhoIsActive_Blocking AS SELECT 1 AS Dummy')
GO

ALTER PROCEDURE dbo.usp_WhoIsActive_Blocking
	@p_Collection_time_Start datetime = NULL, @p_Collection_time_End datetime = NULL, @p_Program_Name nvarchar(256) = NULL, @p_WaitTime_Seconds BIGINT = NULL,
	@p_Help bit = 0, @p_Verbose bit = 0
AS 
BEGIN
	/*	Created By:			Ajay Dwivedi (sqlagentservice@gmail.com)
		Version:			0.1
		Permission:			https://github.com/imajaydwivedi/SQLDBA-SSMS-Solution/blob/master/sp_WhatIsRunning/Certificate%20Based%20Authentication.sql
		Updates:			May 12, 2019 - Get Blocking Details
							May 23, 2019 - Add one more parameter to filter on BlockTime(Seconds)
	*/
	SET NOCOUNT ON;

	DECLARE @_errorMSG VARCHAR(MAX);
	DECLARE @_errorNumber INT;

	IF @p_Help = 1
	BEGIN
		IF @p_Verbose=1 
			PRINT	'
/*	******************** Begin:	@p_Help = 1 *****************************/';

		-- VALUES constructor method does not work in SQL 2005. So using UNION ALL
		SELECT	[Parameter Name], [Data Type], [Default Value], [Parameter Description], [Supporting Parameters]
		FROM	(SELECT	'!~~~ Version ~~~~!' as [Parameter Name],'Information' as [Data Type],'0.1' as [Default Value],'Last Updated - 23/May/2019' as [Parameter Description], 'https://github.com/imajaydwivedi/SQLDBA-SSMS-Solution' as [Supporting Parameters]
					--
				UNION ALL
					--
				SELECT	'@p_Help' as [Parameter Name],'BIT' as [Data Type],'0' as [Default Value],'Displays this help message.' as [Parameter Description], '' as [Supporting Parameters]
					--
				UNION ALL
					--
				SELECT	'@p_Collection_time_Start','datetime',NULL,'Start time in format ''May 17 2019 01:45AM''.', '[@p_Collection_time_End] [,@p_Program_Name] [,@p_Verbose]' as [Supporting Parameters]
					--
				UNION ALL
					--
				SELECT	'@p_Collection_time_End','datetime',NULL,'End time in format ''May 17 2019 01:45AM''.', '[@p_Collection_time_Start] [,@p_Program_Name] [,@p_Verbose]' as [Supporting Parameters]
					--
				UNION ALL
					--
				SELECT	'@p_WaitTime_Seconds','bigint',NULL,'Lock Time Threshold in seconds to filter the blocking resultset.', '[@p_Collection_time_Start] [,@p_Collection_time_End] [,@p_Program_Name] [,@p_Verbose]' as [Supporting Parameters]
				--
				UNION ALL
					--
				SELECT	'@p_Program_Name','VARCHAR(125)',NULL,'value that would match [program_name] column of DBA..whoIsActive_ResultSets table.', '[@p_Collection_time_Start] [,@p_Collection_time_End] [,@p_Verbose]' as [Supporting Parameters]
				--
				UNION ALL
					--
				SELECT	'@p_Verbose','BIT','0','This present all background information that can be used to debug procedure working.', 'All parameters supported' as [Supporting Parameters]
				) AS Params; --([Parameter Name], [Data Type], [Default Value], [Parameter Description], [Supporting Parameters]);


		IF @p_Verbose = 1 
			PRINT	'/*	******************** End:	@p_Help = 1 *****************************/
';
	END
	ELSE
	BEGIN
		IF @p_Verbose = 1
			PRINT 'Evaluating values of @p_Collection_time_Start and @p_Collection_time_End';

		IF @p_Collection_time_Start IS NULL AND @p_Collection_time_End IS NULL
			SELECT	@p_Collection_time_Start = DATEADD(minute,-120,getdate()), @p_Collection_time_End = GETDATE();
		ELSE IF @p_Collection_time_Start IS NULL
			SELECT @p_Collection_time_Start = DATEADD(minute,-120,@p_Collection_time_End);
	
		IF @p_Collection_time_End IS NULL AND @p_Collection_time_Start IS NOT NULL
			SELECT	@p_Collection_time_End = DBA.dbo.fn_GetNextCollectionTime(@p_Collection_time_Start);

		IF @p_WaitTime_Seconds IS NOT NULL AND @p_WaitTime_Seconds <= 0
		BEGIN
			SET @_errorMSG = 'Kindly provide value for following parameters:-'+char(10)+char(13)+'@p_Collection_time_Start, @p_Collection_time_End';
			IF (select CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)),charindex('.',CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)))-1) AS INT)) >= 12
				EXECUTE sp_executesql N'THROW 50000,@_errorMSG,1',N'@_errorMSG VARCHAR(200)', @_errorMSG;
			ELSE
				EXECUTE sp_executesql N'RAISERROR (@_errorMSG, 16, 1)', N'@_errorMSG VARCHAR(200)', @_errorMSG;
		END

		IF @p_Verbose = 1
		BEGIN
			PRINT '@p_Collection_time_Start = '''+CAST(@p_Collection_time_Start AS VARCHAR(35))+'''';
			PRINT '@p_Collection_time_End = '''+CAST(@p_Collection_time_End AS VARCHAR(35))+'''';
		END
			
		IF OBJECT_ID('tempdb..#BlockingTree') IS NOT NULL
			DROP TABLE #BlockingTree;

		;WITH T_BLOCKERS AS
		(
			-- Find block Leaders
			SELECT	[collection_time], [TimeInMinutes], [session_id], 
					[sql_text] = REPLACE(REPLACE(REPLACE(REPLACE(CAST([sql_text] AS VARCHAR(MAX)),char(13),''),CHAR(10),''),'<?query --',''),'--?>',''), 
					[login_name], [wait_info], [blocking_session_id], [blocking_head] = cast(NULL as int),
					[status], [open_tran_count], [host_name], [database_name], [program_name],
					r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[reads], r.[writes], r.[physical_reads],
					[LEVEL] = CAST (REPLICATE ('0', 4-LEN (CAST (r.session_id AS VARCHAR))) + CAST (r.session_id AS VARCHAR) AS VARCHAR (1000))
			FROM	[dbo].WhoIsActive_ResultSets AS r
			WHERE	(r.collection_time >= @p_Collection_time_Start AND r.collection_time <= @p_Collection_time_End)
				AND	(r.blocking_session_id IS NULL OR r.blocking_session_id = r.session_id)
				AND EXISTS (SELECT R2.session_id FROM [dbo].WhoIsActive_ResultSets AS R2 
							WHERE R2.collection_Time = r.collection_Time AND R2.blocking_session_id IS NOT NULL 
								AND R2.blocking_session_id = r.session_id AND R2.blocking_session_id <> R2.session_id
								AND (@p_Program_Name IS NULL OR R2.program_name = @p_Program_Name)
							)
			--	
			UNION ALL
			--
			SELECT	r.[collection_time], r.[TimeInMinutes], r.[session_id], 
					[sql_text] = REPLACE(REPLACE(REPLACE(REPLACE(CAST(r.[sql_text] AS VARCHAR(MAX)),char(13),''),CHAR(10),''),'<?query --',''),'--?>',''), 
					r.[login_name], r.[wait_info], r.[blocking_session_id], [blocking_head] = cast(COALESCE(B.[blocking_head],B.session_id) as int),
					r.[status], r.[open_tran_count], r.[host_name], r.[database_name], r.[program_name],
					r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[reads], r.[writes], r.[physical_reads],
					CAST (B.LEVEL + RIGHT (CAST ((1000 + r.session_id) AS VARCHAR (100)), 4) AS VARCHAR (1000)) AS LEVEL
			FROM	[dbo].WhoIsActive_ResultSets AS r
			INNER JOIN 
					T_BLOCKERS AS B
				ON	r.collection_time = B.collection_time
				AND	r.blocking_session_id = B.session_id
			WHERE	r.blocking_session_id <> r.session_id
		)
		SELECT	[collection_time], 
				[BLOCKING_TREE] = N'    ' + REPLICATE (N'|         ', LEN (LEVEL)/4 - 1) 
								+	CASE	WHEN (LEN(LEVEL)/4 - 1) = 0
											THEN 'HEAD -  '
											ELSE '|------  ' 
									END
								+	CAST (r.session_id AS NVARCHAR (10)) + N' ' + (CASE WHEN LEFT(r.[sql_text],1) = '(' THEN SUBSTRING(r.[sql_text],CHARINDEX('exec',r.[sql_text]),LEN(r.[sql_text]))  ELSE r.[sql_text] END),
				[session_id], [blocking_session_id], [blocking_head],
				[WaitTime(Seconds)] = COALESCE([lock_time(UnExpected)], [lock_time(1)],[lock_time(2)],[lock_time(x)])/1000,
				w.lock_text,
				[sql_commad] = CONVERT(XML, '<?query -- '+char(13)
								+ (CASE WHEN LEFT([sql_text],1) = '(' THEN SUBSTRING([sql_text],CHARINDEX('exec',[sql_text]),LEN([sql_text]))  ELSE [sql_text] END)
								+ char(13)+'--?>'), 
				[host_name], [database_name], [login_name], [program_name],	[wait_info], [open_tran_count]
				,r.[CPU], r.[tempdb_allocations], r.[tempdb_current], r.[reads], r.[writes], r.[physical_reads] --, r.[query_plan]
				--,[Blocking_Order] = DENSE_RANK()OVER(ORDER BY collection_time, LEVEL ASC)
				,LEVEL
		INTO	#BlockingTree
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
															THEN CASE	WHEN CHARINDEX('/',lock_text) = 0
																		THEN CAST(SUBSTRING(lock_text,6,CHARINDEX('ms)',lock_text)-6) AS bigint)
																		ELSE CAST(SUBSTRING(lock_text,CHARINDEX('/',lock_text)+1,CHARINDEX('ms)',lock_text)-CHARINDEX('/',lock_text)-1) AS bigint)
																		END
															ELSE NULL
															END
												ELSE NULL		
												END
						,[lock_time(x)] = CASE WHEN lock_text IS NOT NULL AND CHARINDEX(':',lock_text) <> 0
												THEN CASE	WHEN CAST(SUBSTRING(lock_text,2,CHARINDEX('x:',lock_text)-2) AS INT) > 2 AND CHARINDEX('/',lock_text) = 0
															THEN CAST(SUBSTRING(lock_text,6,CHARINDEX('ms)',lock_text)-6) AS bigint)
															WHEN CAST(SUBSTRING(lock_text,2,CHARINDEX('x:',lock_text)-2) AS INT) > 2 AND (LEN(lock_text)-LEN(REPLACE(lock_text,'/','')) = 1)
															THEN CAST(SUBSTRING(lock_text,CHARINDEX('/',lock_text)+1,CHARINDEX('ms)',lock_text)-CHARINDEX('/',lock_text)-1) AS bigint)
															WHEN CAST(SUBSTRING(lock_text,2,CHARINDEX('x:',lock_text)-2) AS INT) > 2 AND (LEN(lock_text)-LEN(REPLACE(lock_text,'/','')) = 2)
															THEN CAST(SUBSTRING(lock_text, CHARINDEX('/',lock_text,CHARINDEX('/',lock_text)+1)+1, CHARINDEX('ms)',lock_text)-CHARINDEX('/',lock_text,CHARINDEX('/',lock_text)+1)-1) AS bigint)
															ELSE NULL
															END
												ELSE NULL		
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
			) AS w;	

		SELECT	* FROM #BlockingTree AS b
		WHERE	@p_WaitTime_Seconds IS NULL
		OR	(	CASE WHEN	blocking_session_id IS NULL AND NOT EXISTS (SELECT i.* FROM #BlockingTree as i WHERE i.collection_time = b.collection_time AND i.blocking_head = b.session_id AND i.[WaitTime(Seconds)] >= @p_WaitTime_Seconds)
					 THEN	0
					 WHEN	[WaitTime(Seconds)] < @p_WaitTime_Seconds AND NOT EXISTS (SELECT i.* FROM #BlockingTree as i WHERE i.collection_time = b.collection_time AND i.blocking_session_id = b.session_id AND i.[WaitTime(Seconds)] >= @p_WaitTime_Seconds)
					 THEN	0
					 ELSE	1
					 END
			) = 1
		ORDER BY collection_time, LEVEL ASC;
	END
END
GO

/*
EXEC DBA.dbo.usp_WhoIsActive_Blocking @p_Collection_time_Start = 'May 12 2019 11:30AM', @p_Collection_time_End = 'May 12 2019 01:30PM' 
										,@p_WaitTime_Seconds = 300
										--,@p_Program_Name = 'SQL Job = <job name>';
*/
