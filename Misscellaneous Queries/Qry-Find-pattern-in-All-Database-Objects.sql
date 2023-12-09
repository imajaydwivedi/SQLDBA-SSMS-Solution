set quoted_identifier off;

exec sp_msforeachdb "
use [?];
SELECT db_name() as dbName, OBJECT_NAME(object_id) as objectName, *
    FROM sys.sql_modules with (nolock)
    WHERE 1 = 1 
	--and OBJECTPROPERTY(object_id, 'IsProcedure') = 1
    AND definition LIKE '%DBA JOB Failure Report%'
"
