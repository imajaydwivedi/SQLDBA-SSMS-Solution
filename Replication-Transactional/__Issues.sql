https://social.msdn.microsoft.com/Forums/en-US/de898204-7ef7-4faf-9ce6-6a602815e012/snapshot-agent-showing-red-mark-in-replication-monitormerge-replication?forum=sqlreplication

repl_clearcache

The subscription(S) have been marked inactive and must be reinitialized.
https://www.msqlserver.net/2015/03/the-subscriptions-have-been-marked.html
https://abhishekdwivedisite.wordpress.com/2017/12/22/retention-in-sql-server-transaction-replication/


There are currently facing two types of replication issues:
  ISSUE 1 -- Where replication just seem to be stuck. We can see that messages are been read from the log files but it seems that it is not getting to the distributor server from where it could go to the subscriber
 ISSUE 2 � Where replication seems to slow and though it has read messages from the log file and transferred that data to the distribution database, those transactions see delay in getting applied to the subscriber (happens mostly with thFacebookic database)

  Following is a more detailed analysis/resolution/workarounds for each of these issues

ISSUE 1� Where replication just seem to be stuck. We can see that messages are been read from the log files but it seems that it is not getting to the distributor server from where it could go to the subscriber

Usually during this issue, we see that the log reader says it is delivering transactions, but the distribution agent says that there are no transactions to replicate

This happens because of this wait type REPL_SCHEMA_ACCESS. �used by synchronize memory access to prevent multiple log reader to corrupt internal structures on the publishers. Each time log reader agent runs sp_replcmds, it needs to access memory buffer. If it results in growing the buffer, the action needs to be synchronized among log reader agents with REPL_SCHEMA_ACCESS. Contention can be seen on this wait type if you have many published databases on a single publisher with transactional replication and the published databases are very active."

What this means that there is just too many threads to be read from the log reader agent�s reader threads which eventually results in the REPL_SCHEMA_ACCESS wait type and freezes the replication. More details can be read from this link below
https://techcommunity.microsoft.com/t5/sql-server-support/repl-schema-access-wait-type/ba-p/318336

There is a fix for this wait type in sql server 2016 and sql server 2017, but our publisher is 2008 R2 and there is no fix for this 
https://support.microsoft.com/en-us/help/4488036/fix-repl-schema-access-wait-issues-when-there-are-multiple-publisher-d


As a workaround, we first need to verify if we are encountering this wait type. We could do that by executing the following command under the context of the distribution database

select db_name(dbid), hostprocess, status,blocked,* from sys.sysprocesses where program_name like '%logread%'

and then look at the 'lastwaittyep' column for this wait type. If we see that the value is �REPL_SCHEMA_ACCESS� then we do the following:

Since there is no fix, as a workaround we can first start off by stopping the logreader agent for 10 minutes for each of the troubled databases one at a time. What that will do is it will reduce the contention on the log reader agent buffer pool reads. For example:
we could start off by doing this with YouTubeFiltered database for 10 minutes....restart the log agent back 
then do the same for StackOverflow and stop the log reader agent for 10 minutes ...restart the log reader agent back
then do the same for FacebookFiltered and stop the log reader agent for 10 minutes .... restart the log reader agent back and so forth

if restarting all three does not solve the problem then restart the Distribution server. 


Another workaround is we can try decreasing the polling interval in the YouTubeFiltered log reader agent properties by changing the default from 5 to 3. We made this change on the logreader agent of the YouTubeFiltered by adding this flag �-PollingInterval 3�. We want to see how it behaves with one database before we can make the same changes on other Log reader agent properties. One thing to note is that this property should be changed only when there is no backlog. This recommendation is from the same blog post posted above.



ISSUE 2 � Where replication seems to slow and though it has read messages from the log file and transferred that data to the distribution database, those transactions see delay in getting applied to the subscriber (happens mostly with thFacebookic database)

Usually during this issue we see that the log reader is delivering transactions and the distribution agent is saying "Delivering Replicated Transaction". This happens mostly with the Facebook Replication

According to MS and with the data we have seen, this happens only when there are multiple large transactions passing through. A large transaction is typically classified as something
that is containing more than 10000 commands. One way to confirm this is that we run this following query on the subscriber DB

--	On Subscriber
use StackOverflow;
select transaction_timestamp,* 
from dbo.MSreplication_subscriptions;

This query will give us the last transaction that was successfully applied on the subscriber. We take the value of the first column "transaction_timestamp" and then apply that value to this 
query on the distributor

use distribution 
select  top 100
xx.Xact_seqno, count(*) as Xcount 
from dbo.msrepl_commands xx with (nolock)
where xx.publisher_database_id = 24 and  xx.Xact_seqno > 'this is where you post the transaction_timestamp value'
group by xx.Xact_seqno 
having count(*)> 10000
order by xx.xact_seqno

this result set will give you all the pending transactions that are still waiting to be applied to the subscriber. More than likely you will see large transactions in the queue.

If you want to investigate further as to what each transaction is doing, we need to take the 'xact_seqNo' value and put it in the query below 

sp_browsereplcmds '0x0037689B000C25DC00E0000000000000','0x0037689B000C25DC00E0000000000000' (add 12 zeroes to the Xact_seqno value). This will give you what statement the transaction is actually running

There is no fix for this issue. We just have to wait for these transactions to go through. 

This particular replication delay becomes a problem for one deliverable which is the IPG on DS12. As a fix, one of the suggestions that the application team put forward was that until we upgrade we should continue to run this extract off of XDB12 and continue with log shipping. I am exploring that and will make a decision on Tuesday after some more discussion with the application team. 

I had updated Renuka with all these steps which were followed this morning when we encountered minor delays in replication. This week we will spend more time in putting some remedial fixes around ISSUE # 2 which I explained above. 
