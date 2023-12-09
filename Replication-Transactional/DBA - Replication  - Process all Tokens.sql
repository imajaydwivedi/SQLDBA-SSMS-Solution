use master;
go

set nocount on;
set quoted_identifier on;

declare @c_publication varchar(200);
declare @c_dbName varchar(200);
declare @c_publisher_commit datetime;
declare @c_is_processed bit;
declare @c_tracer_id bigint;
declare @c_id bigint;
declare @id_processed bigint;
if object_id('tempdb..#Repl_TracerTokens_Skipped') is not null
	drop table #Repl_TracerTokens_Skipped;
create table #Repl_TracerTokens_Skipped (id bigint, publication varchar(200));
declare @tsqlString nvarchar(4000);

if object_id('tempdb..#tokenHistory') is not null
	drop table #tokenHistory;
create table #tokenHistory (distributor_latency bigint,	subscriber sysname,	subscriber_db sysname, subscriber_latency bigint, overall_latency bigint);
if object_id('tempdb..#tokenHistoryAllPublications') is not null
	drop table #tokenHistoryAllPublications;
create table #tokenHistoryAllPublications (publication sysname, publisher_commit datetime, distributor_latency bigint, subscriber sysname,	subscriber_db sysname, subscriber_latency bigint, overall_latency bigint, overall_latency_minutes as overall_latency/60);

declare cur_Publication cursor local fast_forward for
	select publication from DBA..Repl_TracerToken_Header h where h.is_processed = 0 group by publication order by publication;

open cur_Publication;
fetch next from cur_Publication into @c_publication;
while @@FETCH_STATUS = 0  
begin
	truncate table #Repl_TracerTokens_Skipped;
	set @id_processed = null;

	declare cur_Tokens cursor local forward_only for
		select id, dbName, publisher_commit, tracer_id, is_processed from DBA..Repl_TracerToken_Header h 
			where h.is_processed = 0 and h.publication = @c_publication 
			order by publisher_commit
		for update of is_processed;

	open cur_Tokens;  
	fetch next from cur_Tokens into @c_id, @c_dbName, @c_publisher_commit, @c_tracer_id, @c_is_processed;
	while @@FETCH_STATUS = 0  
	begin
		truncate table #tokenHistory;

		set @tsqlString = 'use '+quotename(@c_dbName)+';
exec sys.sp_helptracertokenhistory @publication = '''+@c_publication+''', @tracer_id = '+cast(@c_tracer_id as varchar(30))+';';
			
		-- Get history for the tracer token.
		insert #tokenHistory
		exec (@tsqlString);

		if exists(select * from #tokenHistory where overall_latency is null)
		begin
			insert #Repl_TracerTokens_Skipped
			values (@c_id, @c_publication);
		end
		else
		begin
			begin tran
				insert #tokenHistoryAllPublications
					(publication, publisher_commit, distributor_latency, subscriber, subscriber_db, subscriber_latency, overall_latency)
				select @c_publication, @c_publisher_commit, distributor_latency, subscriber, subscriber_db, subscriber_latency, overall_latency
				from #tokenHistory;

				UPDATE DBA..Repl_TracerToken_Header SET is_processed = 1
				WHERE CURRENT OF cur_Tokens;

				set @id_processed = @c_id;
			commit tran
		end

		fetch next from cur_Tokens into @c_id, @c_dbName, @c_publisher_commit, @c_tracer_id, @c_is_processed;
	end
	close cur_Tokens;  
	deallocate cur_Tokens;

	-- Set skip flag for lost tracer tokens
	if @id_processed is not null and exists (select * from #Repl_TracerTokens_Skipped where id < @id_processed)
	begin
		update DBA..Repl_TracerToken_Header set is_processed = 1 
		where publication = @c_publication
		and ID in (select s.id from #Repl_TracerTokens_Skipped s where s.id < @id_processed);
	end

	fetch next from cur_Publication into @c_publication;
end
close cur_Publication;  
deallocate cur_Publication;

insert DBA..[Repl_TracerToken_History]
(publication, publisher_commit, distributor_latency, subscriber, subscriber_db, subscriber_latency, overall_latency
)
select publication, publisher_commit, distributor_latency, subscriber, subscriber_db, subscriber_latency, overall_latency 
from #tokenHistoryAllPublications;
go
