USE DBA
GO

select *
into dbo.sdt_server_inventory_bak
from dbo.sdt_server_inventory

/*
ALTER TABLE dbo.sdt_server_inventory SET ( SYSTEM_VERSIONING = OFF)
go
drop table dbo.sdt_server_inventory
go
drop table dbo.sdt_server_inventory_history
go
*/
create table dbo.sdt_server_inventory
( 	server varchar(500) not null, friendly_name varchar(255) not null,
	sql_instance varchar(255) not null,
	ipv4 varchar(15) null, stability varchar(20) default 'DEV',
	server_owner varchar(500) null,
	is_active bit default 1, monitoring_enabled bit default 1
	
	,valid_from DATETIME2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL
    ,valid_to DATETIME2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL
    ,PERIOD FOR SYSTEM_TIME (valid_from,valid_to)

	,constraint pk_sdt_server_inventory primary key clustered (friendly_name)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.sdt_server_inventory_history))
go
create unique index uq_sdt_server_inventory__server__sql_instance on dbo.sdt_server_inventory (server, sql_instance);
go
create unique index uq_sdt_server_inventory__sql_instance on dbo.sdt_server_inventory (sql_instance);
go
create unique index uq_$($SdtInventoryTable -replace 'dbo.', '')__server__sql_instance on $SdtInventoryTable (server, sql_instance);
go
create unique index uq_$($SdtInventoryTable -replace 'dbo.', '')__sql_instance on $SdtInventoryTable (sql_instance);
go
create index ix_sdt_server_inventory__is_active__monitoring_enabled on dbo.sdt_server_inventory (is_active, monitoring_enabled);
go
alter table dbo.sdt_server_inventory add constraint chk_sdt_server_inventory__stability check ( [stability] in ('DEV', 'UAT', 'QA', 'STG', 'PROD', 'PRODDR', 'STGDR','QADR', 'UATDR', 'DEVDR') )
go