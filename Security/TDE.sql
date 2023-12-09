/* Transparent Database Encryption

Note: Backup/Restore won't be possible without certificate/key
*/
go

use master
go

-- Declare variables
declare @srv_name varchar(125);
declare @encrypt_password nvarchar(255);
declare @cert_name varchar(255);
declare @cert_subject varchar(255);
declare @thumbprint varbinary(64);
declare @crlf nchar(2) = char(10)+char(13);
declare @backup_directory varchar(255);
declare @certificate_path varchar(500);
declare @master_key_path varchar(500);
declare @private_key_path varchar(500);
declare @sql nvarchar(max);

-- Initialize variables
set @srv_name = convert(varchar,SERVERPROPERTY('ServerName'));
set @backup_directory = 'D:\GitHub-Personal\SQLDBA-SSMS-Solution\Sensitive\';
set @encrypt_password = 'S0me$trongP@ssw0rd';
set @cert_name = (@srv_name+'--TDE-Certifice');
set @cert_subject = 'Certificate for TDE';
set @certificate_path = @backup_directory + (case when right(@backup_directory,1) = '\' then '' else '\' end) + @cert_name + '.crt';
set @master_key_path = @backup_directory + (case when right(@backup_directory,1) = '\' then '' else '\' end) + @srv_name + '__master_key.key';
set @private_key_path = @backup_directory + (case when right(@backup_directory,1) = '\' then '' else '\' end) + @srv_name + '__private_key.pvk';

-- Create master key
if not exists (select * from sys.symmetric_keys where name LIKE '%DatabaseMasterKey%')
begin
	set @sql = 'create master key encryption by password = '''+@encrypt_password+'''';
	print @sql;
	exec (@sql);
end
else
    print 'DMK exists';

-- Create certificate
select @thumbprint = c.thumbprint from sys.certificates c 
	where issuer_name = @cert_subject and name = @cert_name;

if @thumbprint is null
begin
	set @sql = 'create certificate '+quotename(@cert_name)+' with subject = '''+@cert_subject+''';';
	print @sql
	exec (@sql);
end
else
	print 'Certificate already exists';

-- Create encryption key
use [StackOverflow2013];
if not exists (select * from sys.dm_database_encryption_keys dek where dek.database_id = DB_ID()
					and dek.encryptor_type = 'CERTIFICATE' and dek.key_length = 128 
					and dek.encryptor_thumbprint = @thumbprint )
begin
	set @sql = 'create database encryption key with algorithm = aes_128'+@crlf+
					+'encryption by server certificate '+quotename(@cert_name)+';';
	print @sql;
	exec (@sql);
end
else
	print 'Database Encryption key exists';

/* Warning: The certificate used for encrypting the database encryption key has not been backed up. You should immediately back up the certificate and the private key associated with the certificate. If the certificate ever becomes unavailable or if you must restore or attach the database on another server, you must have backups of both the certificate and the private key or you will not be able to open the database.
*/
/*
Msg 33103, Level 16, State 1, Line 9
A database encryption key already exists for this database.
------------------------
USE [StackOverflow2013];
ALTER DATABASE CURRENT SET ENCRYPTION OFF;  
GO  

/* Wait for decryption operation to complete, look for a value of 1 in the query below. */  
USE [StackOverflow2013];
SELECT encryption_state, encryption_state_desc, DB_NAME(database_id) as dbName, percent_complete  
FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID();
GO

USE [StackOverflow2013];
DROP DATABASE ENCRYPTION KEY;  
GO
*/
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- Backup Certificate & Master Key
---------------------------------------------------------------------------------------------
use master;

-- Backup master key
set @sql = 'backup master key to file = '''+@master_key_path+''' encryption by password = '''+@encrypt_password+'''';
print @sql;
exec (@sql);

-- Backup certificate
set @sql = 'backup certificate '+quotename(@cert_name)+'
	to file = '''+@certificate_path+'''
	with private key (
		file = '''+@private_key_path+''',
		encryption by password = '''+@encrypt_password+'''
	)';
go

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- Now enable encryption & simulate server failure
---------------------------------------------------------------------------------------------
use master
go
alter database StackOverflow2013 set encryption on;
go

backup database StackOverflow2013 to disk = 'D:\GitHub-Personal\SQLDBA-SSMS-Solution\Sensitive\StackOverflow2013.bak' with copy_only
go

use master
go
drop database StackOverflow2013
go
drop certificate ProtectDataInRestCert;
go
drop master key
go

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- Test restore of database
---------------------------------------------------------------------------------------------
restore database StackOverflow2013 /* Step 3 */
	from disk = 'D:\GitHub-Personal\SQLDBA-SSMS-Solution\Sensitive\StackOverflow2013.bak'
go
/* Msg 33111, Level 16, State 3, Line 67
Cannot find server certificate with thumbprint '0x87B58DC941C6AAAA4482A83A3849010678798F03'.
Msg 3013, Level 16, State 1, Line 67
RESTORE DATABASE is terminating abnormally.
*/

create certificate ProtectDataInRestCert /* Step 2 */
	from file = 'D:\GitHub-Personal\SQLDBA-SSMS-Solution\Sensitive\ProtectDataInRestCert_certificate.crt'
	with private key (
		file = 'D:\GitHub-Personal\SQLDBA-SSMS-Solution\Sensitive\ProtectDataInRestCert_private_key.pvk',
		decryption by password = 'S0me$trongP@ssw0rd'
	);
go
/* Msg 15581, Level 16, State 1, Line 76
Please create a master key in the database or open the master key in the session before performing this operation.
*/

create master key encryption by /* Step 1 */
	password = 'S0meNew$trongP@ssw0rd'
go



/*
use master
go

SELECT DB_NAME(database_id) as dbName, encryption_state_desc, percent_complete,
		dek.encryptor_thumbprint,
		time_elapsed_hrs = DATEDIFF(hour,set_date, encryption_scan_modify_date),
		*
FROM sys.dm_database_encryption_keys  dek
--WHERE database_id = DB_ID();
GO
*/