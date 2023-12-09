--drop table dbo.tde_implementation_details
create table dbo.tde_implementation_details
(
	srv_name varchar(125) not null,
	at_server_name varchar(128) not null,
	server_name varchar(125) not null,
	domain varchar(125) not null,
	server_host_name varchar(125) not null,
	encrypted_databases varchar(125) null,
	total_database_count smallint not null,
	encryption_start_time datetime2 not null default sysdatetime(),
	encryption_end_time datetime2 null,
	local_backup_directory varchar(500) not null,
	remote_backup_directory varchar(500) null,
	certificate_name varchar(125) null,
	certificate_subject varchar(500) null,
	encryption_password varchar(500) null,
	certificate_file_path varchar(500) null,
	master_key_path varchar(500) null,
	private_key_path varchar(500) null,
	files_copied_to_remote bit not null default 0,
	collection_time datetime2 not null default sysdatetime(),
	collected_by varchar(125) not null default suser_name()

	,constraint pk__tde_implementation_details primary key clustered (srv_name, server_name, server_host_name)
);
go