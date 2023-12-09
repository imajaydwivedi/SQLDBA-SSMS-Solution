use DBA
go

declare @start_time datetime = '2022-10-05 15:40:00';
declare @end_time datetime = '2022-10-05 16:53:00';
declare @database_name nvarchar(255) --= 'StackOverflow';
declare @login varchar(255);
declare @program varchar(255) --= 'dbatools';
declare @host varchar(255);
declare @table_name nvarchar(500) --= 'Users';
declare @str_length smallint = 50;
declare @sql_string nvarchar(max);
declare @params nvarchar(max);

set @params = N'@start_time datetime, @end_time datetime, @database_name nvarchar(255), @login varchar(255), @program varchar(255), @host varchar(255), @table_name nvarchar(500), @str_length smallint';

if object_id('tempdb..#queries') is not null drop table #queries;
CREATE TABLE #queries
(
	[grouping-key] [nvarchar](200),
	[cpu_time_minutes] [bigint],
	[cpu_time_seconds_avg] [bigint],
	[logical_reads_gb] [numeric](20, 2),
	[logical_reads_gb_avg] [numeric](20, 2),
	[logical_reads_mb_avg] [numeric](20, 2),
	[writes_gb] [numeric](20, 2),
	[writes_mb] [numeric](20, 2),
	[writes_gb_avg] [numeric](20, 2),
	[writes_mb_avg] [numeric](20, 2),
	[duration_minutes] [bigint],
	[duration_minutes_avg] [bigint],
	[duration_seconds_avg] [bigint],
	[counts] [int]
);

set quoted_identifier off;
set @sql_string = "
;with cte_group as (
	select	[grouping-key] = (case when client_app_name like 'SQL Job = %' then client_app_name else left("+DB_NAME()+".dbo.normalized_sql_text(sql_text,150,0),@str_length) end), 
			[cpu_time_minutes] = sum(cpu_time/1000000)/60,
			[cpu_time_seconds_avg] = sum(cpu_time/1000000)/count(*),
			[logical_reads_gb] = convert(numeric(20,2),sum(logical_reads)*8.0/1024/1024), 
			[logical_reads_gb_avg] = convert(numeric(20,2),sum(logical_reads)*8.0/1024/1024/count(*)),
			[logical_reads_mb_avg] = convert(numeric(20,2),sum(logical_reads)*8.0/1024/count(*)),
			[writes_gb] = convert(numeric(20,2),sum(writes)*8.0/1024/1024),
			[writes_mb] = convert(numeric(20,2),sum(writes)*8.0/1024),
			[writes_gb_avg] = convert(numeric(20,2),sum(writes)*8.0/1024/1024/count(*)),
			[writes_mb_avg] = convert(numeric(20,2),sum(writes)*8.0/1024/count(*)),
			[duration_minutes] = sum(rc.duration_seconds)/60,
			[duration_minutes_avg] = sum(rc.duration_seconds)/60/count(*),
			[duration_seconds_avg] = sum(rc.duration_seconds)/count(*),
			[counts] = count(*)
	from "+DB_NAME()+".dbo.xevent_metrics rc
	where (	rc.event_time between @start_time and @end_time
			or rc.start_time between @start_time and @end_time
		  )
	"+(CASE WHEN @database_name IS NULL THEN "--" ELSE "" END)+"and rc.database_name = @database_name
	"+(CASE WHEN @table_name IS NULL THEN "--" ELSE "" END)+"and rc.sql_text like ('%'+@table_name+'%')
	"+(CASE WHEN @login IS NULL THEN "--" ELSE "" END)+"and rc.username = @login
	"+(CASE WHEN @program IS NULL THEN "--" ELSE "" END)+"and rc.client_app_name = @program
	"+(CASE WHEN @host IS NULL THEN "--" ELSE "" END)+"and rc.client_hostname = @host
	and result = 'OK'
	group by (case when client_app_name like 'SQL Job = %' then client_app_name else left("+DB_NAME()+".dbo.normalized_sql_text(sql_text,150,0),@str_length) end)
)
select *
from cte_group ct
"
set quoted_identifier on;

insert #queries
exec sp_ExecuteSql @sql_string, @params, 
					@start_time, @end_time, @database_name, @login, @program, @host, @table_name, @str_length;

set quoted_identifier off;
set @sql_string = "
select top 200 [Normalized-Text] = q.[grouping-key], rc.sql_text, q.counts, q.cpu_time_seconds_avg, q.logical_reads_gb_avg, duration_seconds_avg, 
		q.cpu_time_minutes, q.logical_reads_gb, q.duration_minutes, rc.event_name,
		rc.database_name, rc.client_app_name, rc.username, rc.client_hostname, rc.row_count
		/* ,q.* ,rc.* */
from #queries q
outer apply (select top 1 * from dbo.xevent_metrics rc 
			where (	rc.event_time between @start_time and @end_time
					or rc.start_time between @start_time and @end_time
				  )
			"+(CASE WHEN @database_name IS NULL THEN "--" ELSE "" END)+"and rc.database_name = @database_name
			"+(CASE WHEN @table_name IS NULL THEN "--" ELSE "" END)+"and rc.sql_text like ('%'+@table_name+'%')
			"+(CASE WHEN @login IS NULL THEN "--" ELSE "" END)+"and rc.username = @login
			"+(CASE WHEN @program IS NULL THEN "--" ELSE "" END)+"and rc.client_app_name = @program
			"+(CASE WHEN @host IS NULL THEN "--" ELSE "" END)+"and rc.client_hostname = @host
			and result = 'OK'
			and q.[grouping-key] = (case when rc.client_app_name like 'SQL Job = %' then rc.client_app_name else left("+DB_NAME()+".dbo.normalized_sql_text(rc.sql_text,150,0),@str_length) end)
			order by rc.cpu_time desc
			) rc
order by q.cpu_time_minutes desc
"
set quoted_identifier on;

exec sp_ExecuteSql @sql_string, @params, 
					@start_time, @end_time, @database_name, @login, @program, @host, @table_name, @str_length;
go
/*
select top 1000 
		sqlsig = DBA.dbo.normalized_sql_text(sql_text,150,0), 
		*
from DBA.dbo.xevent_metrics rc
where rc.event_time >= dateadd(day,-1,getdate())
and rc.database_name = 'Facebook'
and rc.sql_text like '%Posts%'
and result = 'OK'
--order by logical_reads desc
*/

