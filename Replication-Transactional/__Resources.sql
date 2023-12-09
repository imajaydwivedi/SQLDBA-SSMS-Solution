1) SQL Server Transactional Replication A Deep Dive - Drew Furgiuele
	https://www.youtube.com/watch?v=m28K21Widn0
2) PluralSight Course - "SQL Server - Transactional Replication Fundamentals"
3) YouTube - SQL Server Replication
https://www.youtube.com/playlist?list=PLbkU_gVPZ7OT8gcTJQ0uTi9r4uyZJmUcP
4) YouTube - Tuning and Troubleshooting Transactional Replication - Kendal Van Dyke
https://www.youtube.com/watch?v=UBdAAvMMGwo
5) SQL Server Replication Scripts to get Replication Configuration Information
https://www.mssqltips.com/sqlservertip/1808/sql-server-replication-scripts-to-get-replication-configuration-information/
6) https://www.msqlserver.net/2015/03/the-subscriptions-have-been-marked.html
7) https://docs.microsoft.com/en-us/sql/relational-databases/replication/troubleshoot-tran-repl-errors?view=sql-server-2017

8) Add article to transactional publication without generating new snapshot
https://dba.stackexchange.com/questions/12725/add-article-to-transactional-publication-without-generating-new-snapshot

9)
https://docs.microsoft.com/en-us/sql/relational-databases/system-tables/msdistribution-history-transact-sql?view=sql-server-ver15
https://stackoverflow.com/questions/16482454/distribution-dbo-msdistribution-history-comments-explanation
https://flylib.com/books/en/2.908.1.93/1/
http://maginaumova.com/the-replication-agent-has-not-logged-a-progress-message-in-10-minutes/
https://dba.stackexchange.com/questions/86794/how-to-restart-the-distributor-agent-of-transactional-replication
https://dba.stackexchange.com/questions/88923/replication-monitor-information-using-t-sql

10) Script out Replication
https://www.sqlservercentral.com/articles/script-sql-server-replication-with-powershell

Rules:-
-----
1) Log Reader agent always resides at Distributor
2) Distribution Agent 
	> resides at Distributer for "Push" subscription
	> resides at Subscriber for "Pull" subscription

Find Replication Jobs using query "01) Get Replication Jobs.sql"


SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

-- :CONNECT distributor
use distribution;
	-- Find all replication related servers
	SELECT * FROM MSreplservers;
	-- replication commands stored in distribution database
	exec sp_browsereplcmds
	-- Returns one row for each tracer token that has been inserted into a publication to determine latency
	exec sp_helptracertokens @publication = 'DBA_DBA', @publisher = ''
	-- one row for each publication 
	select * from MSpublications where publication = 'DBA_DBA'
	-- one row for remote Publisher supported by the local Distributor
	select * from msdb..MSdistpublishers 
	-- one row for each Publisher/Publisher database pair serviced by the local Distributor
	select * from MSpublisher_databases
	--  one row for each Distribution Agent running at local Distributor
	select * from MSdistribution_agents
	-- history rows for the Distribution Agents associated with the local Distributor
	select * from MSdistribution_history 
	-- one row for each Log Reader Agent running at local Distributor
	select * from MSlogreader_agents
	-- one row for each Snapshot Agent job running at local Distributor
	select * from MSsnapshot_agents
	-- history rows for the Log Reader Agents associated with the local Distributor
	select * from MSlogreader_history 
	-- rows of replicated commands
	select * from MSrepl_commands;
	-- rows with extended Distribution Agent and Merge Agent failure information
	select * from MSrepl_errors
	-- one row for each replicated transaction
	select * from MSrepl_transactions
	-- one row for each published article in a subscription serviced by the local Distributor
	select * from MSsubscriptions
	-- tracer token records inserted into a publication
	select * from MStracer_tokens where publication_id = 1137
	-- all tracer tokens that have been received at the Subscriber
	select * from MStracer_history where parent_tracer_id = -2146562275
	-- information about the conditions causing a replication alert to fire
	select * from msdb..sysreplicationalerts
	--  cached data used by Replication Monitor, with one row for each monitored subscription
	select * from MSreplication_monitordata
	-- contains one row for each Publisher/Subscriber pair that is being pushed subscriptions from the local Distributor
	select * from MSsubscriber_info
	-- one row for each Publisher/Publisher database pair serviced by the local Distributor
	select * from MSpublisher_databases

	-- Get Publishers View
	exec sp_replmonitorhelppublisher
	-- Get All Publications
	exec sp_replmonitorhelppublication
	-- Get All Subscriptions for Transactional Replication
	exec sp_replmonitorhelpsubscription @publication_type = 0
	-- Get pending commands
	SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
	exec sp_replmonitorsubscriptionpendingcmds @publisher = 'MSI', @publisher_db = 'DBA', @publication = 'DBA_Arc', 
																@subscriber = 'MSI\SQL2019', @subscriber_db = 'DBA', @subscription_type = 0;


-- :CONNECT publisher
	-- Determines whether a Distributor is installed on a server
	exec sp_get_distributor 

	use DBA;
	-- find publications for database
	exec sp_helppublication
	-- one row for each publication defined in the database
	select * from syspublications
	-- one row for each subscription in the database
	select * from syssubscriptions 
	-- Get article information
	exec sp_helparticle @publication = 'DBA_DBA'
	-- Returns replication statistics about latency, throughput, and transaction count for each published database
	exec sp_replcounters
	-- Returns the commands for transactions marked for replication
		--  is used by the log reader process in transactional replication
	exec sp_replcmds 
	-- Returns a result set of all the transactions in the publication database transaction log that are marked for replication but have not been marked as distributed
	exec sp_repltrans 
	-- Returns the commands for transactions marked for replication in readable format
	exec sp_replshowcmds
	-- Returns one row for each tracer token that has been inserted into a publication to determine latency
	exec sp_helptracertokens @publication = 'DBA_DBA'
	-- This procedure posts a tracer token into the transaction log at the Publisher and begins the process of tracking latency statistics
	exec sp_posttracertoken

-- :CONNECT subscriber

	use DBARepl;
	-- one row of replication information for each Distribution Agent servicing the local Subscriber database
	select * from MSreplication_subscriptions


USE [distribution];
-- Get the publications
SELECT DISTINCT  
			srv.srvname publication_server  
			, p.publisher_db 
			, p.publication publication_name 
			, ss.srvname subscription_server 
			, s.subscriber_db 
			, da.name AS distribution_agent_job_name 
FROM MSpublications p 
JOIN MSsubscriptions s ON p.publication_id = s.publication_id 
JOIN MSreplservers ss ON s.subscriber_id = ss.srvid 
JOIN MSreplservers srv ON srv.srvid = p.publisher_id 
JOIN MSdistribution_agents da ON da.publisher_id = p.publisher_id  
     AND da.subscriber_id = s.subscriber_id 
--WHERE p.publication = 'DBA_DBA'
ORDER BY 1,2,3;

