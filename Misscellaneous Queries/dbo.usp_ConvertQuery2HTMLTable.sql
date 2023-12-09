--	https://www.mssqltips.com/sqlservertip/5025/stored-procedure-to-generate-html-tables-for-sql-server-query-output/
/*	Stored procedure to generate HTML tables for SQL Server query output
*/
USE tempdb
GO
IF OBJECT_ID('dbo.usp_ConvertQuery2HTMLTable') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_ConvertQuery2HTMLTable AS RETURN 0;')
GO

ALTER PROC dbo.usp_ConvertQuery2HTMLTable (@SQLQuery NVARCHAR(3000))
AS
BEGIN
   DECLARE @columnslist NVARCHAR (1000) = ''
   DECLARE @restOfQuery NVARCHAR (2000) = ''
   DECLARE @DynTSQL NVARCHAR (3000)
   DECLARE @FROMPOS INT

   SET NOCOUNT ON

   SELECT @columnslist += 'ISNULL (' + NAME + ',' + '''' + ' ' + '''' + ')' + ','
   FROM sys.dm_exec_describe_first_result_set(@SQLQuery, NULL, 0)

   SET @columnslist = left (@columnslist, Len (@columnslist) - 1)
   SET @FROMPOS = CHARINDEX ('FROM', @SQLQuery, 1)
   SET @restOfQuery = SUBSTRING(@SQLQuery, @FROMPOS, LEN(@SQLQuery) - @FROMPOS + 1)
   SET @columnslist = Replace (@columnslist, '),', ') as TD,')
   SET @columnslist += ' as TD'
   SET @DynTSQL = CONCAT (
         'SELECT (SELECT '
         , @columnslist
         ,' '
         , @restOfQuery
         ,' FOR XML RAW (''TR''), ELEMENTS, TYPE) AS ''TBODY'''
         ,' FOR XML PATH (''''), ROOT (''TABLE'')'
         )

   EXEC (@DynTSQL)
   SET NOCOUNT OFF
END
GO
