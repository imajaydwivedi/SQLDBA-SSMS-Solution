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

	update dbo.person WITH (UPDLOCK, SERIALIZABLE)
	set address = 'Address for '+name
	where id = 105;

	select @@TRANCOUNT;

	/* EXECUTE IN ANOTHER SESSION RIGHT AWAY

	-- Will it block update on another data page??
	update dbo.person WITH (UPDLOCK, SERIALIZABLE) 
	set address = 'Address for '+name
	where id = 30;

	-- Will it block insert on another data page??
	insert into dbo.person (id, [name], [address])
	values (102, 'Person_102', 'Address of Person_102');

	-- Will it block same row update in another session?
	update dbo.person WITH (UPDLOCK, SERIALIZABLE) 
	set address = 'Address for '+name
	where id = 15;	

	-- Will it block same row update in another session?
	update dbo.person WITH (UPDLOCK, SERIALIZABLE) 
	set address = 'Address for '+name
	where id = 105;	

	-- Will it block new row insert in another session?
	INSERT INTO dbo.person (id, name, address)
	values (105, 'Person_105', 'Address of Person_105');

	-- Will it block new row insert in another session?
	INSERT INTO dbo.person (id, name, address)
	values (120, 'Person_120', 'Address of Person_120');
	*/

waitfor delay '00:01:00';

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
