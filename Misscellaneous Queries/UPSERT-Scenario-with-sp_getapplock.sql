/*
-- create dummy table
create table dbo.person (id int primary key not null, name varchar(50) not null, address char(1000) not null);

truncate table dbo.person;

-- Insert 100 dummy records into dbo.person
WITH Numbers AS (
    SELECT TOP 100 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects  -- any sufficiently large table
)
INSERT INTO dbo.person (id, name, address)
SELECT 
    n,
    CONCAT('Person_', n),  -- Name like Person_1, Person_2...
    LEFT(REPLICATE('Address_', 200) + CAST(n AS VARCHAR), 1000)  -- 1000-char address
FROM Numbers;

select * from dbo.person;
*/

BEGIN TRAN;
	declare @id int = 105;
	declare @resource nvarchar(255);

	set @resource = 'person_id-'+convert(varchar(255),@id);
	
	exec sp_getapplock @Resource = @resource, @LockMode = 'Exclusive';

	update dbo.person
	set address = 'Address for '+name
	where id = 105;

	select @@TRANCOUNT;

	/*	--- Insert Same Row in another Session ---------
		begin tran

			declare @id int = 105;
			declare @resource nvarchar(255);

			set @resource = 'person_id-'+convert(varchar(255),@id);
	
			exec sp_getapplock @Resource = @resource, @LockMode = 'Exclusive';

		-- Will it block new row insert in another session?
			INSERT INTO dbo.person (id, name, address)
			values (105, 'Person_105', 'Address of Person_105');

		commit tran
	*/

	/*	--- Insert Different Row in another Session ---------
		begin tran

			declare @id int = 101;
			declare @resource nvarchar(255);

			set @resource = 'person_id-'+convert(varchar(255),@id);
	
			exec sp_getapplock @Resource = @resource, @LockMode = 'Exclusive';

		-- Will it block new row insert in another session?
			INSERT INTO dbo.person (id, name, address)
			values (101, 'Person_101', 'Address of Person_101');

		commit tran
	*/

	exec sp_releaseapplock @Resource = @resource;

--waitfor delay '00:01:00';

while @@trancount > 0
begin
    COMMIT TRAN
	-- ROLLBACK TRAN
end


/*
https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide?view=sql-server-ver16#:~:text=Use%20the%20following%20table%20to%20determine%20the%20compatibility%20of%20all%20the%20lock%20modes%20available%20in%20the%20Database%20Engine.

-- Get me locks head
SELECT 
    tl.resource_type,
    tl.resource_subtype,
    tl.resource_description,
    tl.resource_associated_entity_id AS object_id,
    tl.request_mode,
    tl.request_status,
    DB_NAME(tl.resource_database_id) AS database_name,
    tl.request_session_id
FROM sys.dm_tran_locks AS tl
WHERE tl.request_session_id = 67
ORDER BY tl.resource_type, tl.request_mode;

*/
