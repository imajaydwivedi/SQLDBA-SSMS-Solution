-- Start snapshot agent. Execute on Publisher Db
  -- Execute on [PublisherServer]
use [<PublisherDbNameHere>]
exec sp_startpublication_snapshot
			@publication = N'<PublicationNameHere>'
go

