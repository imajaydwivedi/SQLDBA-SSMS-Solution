--	Return Query Output as HTML Table
--	https://github.com/imajaydwivedi/SQLDBA-SSMS-Solution/issues/1

USE SQLDBATools
GO

SELECT	i.Instance_ID
		,i.Name
		,i.Version
FROM	dbo.Instance as i

SELECT a.*  
FROM OPENROWSET('SQLNCLI', 'Server=DbaTestServerName;Trusted_Connection=yes;',  
     'EXEC tempdb..[usp_AnalyzeSpaceCapacity] @help = 1') AS a;

/*
Msg 2812, Level 16, State 62, Line 19
Could not find stored procedure 'THROW'.
*/