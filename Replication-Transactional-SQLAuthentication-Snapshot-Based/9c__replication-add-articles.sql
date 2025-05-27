-- Adding the transactional articles. Execute on Publisher Db
  -- Execute on [PublisherServer]
use [<PublisherDbNameHere>]
exec sp_addarticle	
				@publication = N'<PublicationNameHere>',
				@article = N'<PublishedTableNameHere>',
				@source_owner = N'<PublishedTableSchemaNameHere>',
				@source_object = N'<PublishedTableNameHere>',
				@destination_owner = N'<PublishedTableSchemaNameHere>',
				@destination_table = N'<PublishedTableNameHere>',
				@ins_cmd = N'CALL [sp_MSins_<PublishedTableSchemaNameHere><PublishedTableNameHere>]',
				@del_cmd = N'CALL [sp_MSdel_<PublishedTableSchemaNameHere><PublishedTableNameHere>]',
				@upd_cmd = N'CALL [sp_MSupd_<PublishedTableSchemaNameHere><PublishedTableNameHere>]',
				@type = N'logbased',
				@pre_creation_cmd = N'truncate',
				@schema_option = 0x000000000803508F,
				@identityrangemanagementoption = N'manual',
				@status = 24,
				@vertical_partition = N'false';
GO

