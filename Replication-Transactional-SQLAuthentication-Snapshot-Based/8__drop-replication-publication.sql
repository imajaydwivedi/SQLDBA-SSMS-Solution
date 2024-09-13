-- Dropping the transactional subscriptions on Publisher
  -- Execute on [PublisherServer]
use [<PublisherDbNameHere>]
exec sp_dropsubscription
		@publication = N'<PublicationNameHere>', 
		@subscriber = N'<SubscriberServerNameHere>', 
		@destination_db = N'<SubscriberDbNameHere>', 
		@article = N'all'
GO

/*
use [<PublisherDbNameHere>]
exec sp_droparticle @article = N'<PublishedTableNameHere>', @publication = N'<PublicationNameHere>', @force_invalidate_snapshot = 1
GO
*/

-- Execute <sp_droparticle> for each table

-- Dropping the transactional publication on Publisher
  -- Execute on [PublisherServer]
use [<PublisherDbNameHere>]
exec sp_droppublication @publication = N'<PublicationNameHere>'
GO

