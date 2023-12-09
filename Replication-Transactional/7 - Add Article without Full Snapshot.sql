Adding new article without generating a complete snapshot :

1)      Make sure that your publication has IMMEDIATE_SYNC and ALLOW_ANONYMOUS properties set to FALSE or 0.

Use yourDB
select immediate_sync , allow_anonymous from syspublications

If either of them is TRUE then modify that to FALSE by using the following
command

EXEC sp_changepublication @publication = 'yourpublication', @property =N'allow_anonymous', @value='False' 
Go
EXEC sp_changepublication @publication = 'yourpublication', @property =N'immediate_sync', @value='false'
Go

2)      Now add the article to the publication

Use yourDB
EXEC sp_addarticle @publication = 'yourpublication', @article ='test',
@source_object='test', @force_invalidate_snapshot=1

If you do not use the @force_invalidate_snapshot option then you will receive the
following error
Msg 20607, Level 16, State 1, Procedure sp_MSreinit_article, Line 99
Cannot make the change because a snapshot is already generated. Set
@force_invalidate_snapshot to 1 to force the change and invalidate the existing snapshot.

3)      Verify if you are using CONCURRENT or NATIVE method for synchronization by running the following command.

Use yourdb
select sync_method from syspublications

If the value is 3 or 4 then it is CONCURRENT and if it is 0 then it is NATIVE.
For more information check
http://msdn.microsoft.com/en-us/library/ms189805.aspx

4)      Then add the subscription for this new article using the following command

             EXEC sp_addsubscription @publication = 'yourpublication', @article = 'test', 
             @subscriber ='subs_servername', @destination_db = 'subs_DBNAME', 
             @reserved='Internal'

If you are using the NATIVE  method for synchronization then the parameter
@reserved=’Internal’ is optional but there is no harm in using it anyways. But if it is CONCURRENT then you have to use that parameter. Else the next time you run the snapshot agent it is going to generate a snapshot for all the articles.

Lastly start the SNAPSHOT AGENT job from the job activity monitor. To find
the job name follow these steps.

·        select * from msdb..sysjobs where name like '%yourpublication%'
·        Right click on each of those jobs and find which one contains the step    
      ‘Snapshot Agent startup message’. This is the job that you want to      
                         start from the first step.

Verify that the snapshot was generated for only one article.