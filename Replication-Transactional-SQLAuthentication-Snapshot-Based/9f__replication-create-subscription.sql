-- Adding the transactional subscriptions. Execute on Publisher Db
  -- Execute on [PublisherServer]
use [<PublisherDbNameHere>]
exec sp_addsubscription
		@publication = N'<PublicationNameHere>',
		@subscriber = N'<SubscriberServerNameHere>',
		@destination_db = N'<SubscriberDbNameHere>',
		@subscription_type = N'Push', 
		@sync_type = N'automatic', 
		@article = N'all', 
		@update_mode = N'read only', 
		@subscriber_type = 0;
go

-- Add distribution agent. Execute on Publisher Db
  -- Execute on [PublisherServer]
use [<PublisherDbNameHere>]
exec sp_addpushsubscription_agent
		@publication = N'<PublicationNameHere>', 
		@subscriber = N'<SubscriberServerNameHere>', 
		@subscriber_db = N'<SubscriberDbNameHere>',
		@subscriber_password = N'<ReplLoginPasswordHere>',
		@subscriber_login = N'<ReplLoginNameHere>', 
		@subscriber_security_mode = 0, 
		@frequency_type = 64, 
		@frequency_interval = 1, 
		@frequency_relative_interval = 1, 
		@frequency_recurrence_factor = 0, 
		@frequency_subday = 4, 
		@frequency_subday_interval = 5, 
		@active_start_time_of_day = 0, 
		@active_end_time_of_day = 235959, 
		@active_start_date = 0, 
		@active_end_date = 0, 
		@dts_package_location = N'Distributor'
GO

