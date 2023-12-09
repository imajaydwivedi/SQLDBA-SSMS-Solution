/*	https://www.erikdarlingdata.com/sp_humanevents/
*/
-- Get compilations. Run this from SQL Notebooks to save the results
exec dbo.sp_HumanEvents @event_type = 'compilations', @seconds_sample = 600;

-- Setup XEvent for Compilations
exec dbo.sp_HumanEvents @event_type = N'compilations', @keep_alive = 0;

-- Save the data into Tables
exec dbo.sp_HumanEvents @output_database_name = N'DBA', @output_schema_name = N'dbo';

/*Compiles, only on newer versions of SQL Server*/
SELECT TOP 1000 * FROM dbo.HumanEvents_CompilesByDatabaseAndObject;
SELECT TOP 1000 * FROM dbo.HumanEvents_CompilesByQuery;
SELECT TOP 1000 * FROM dbo.HumanEvents_CompilesByDuration;

/*Otherwise*/
SELECT TOP 1000 * FROM dbo.HumanEvents_Compiles_Legacy;
