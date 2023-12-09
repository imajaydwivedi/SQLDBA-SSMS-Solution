CREATE DATABASE [ShrinkTest]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'ShrinkTest', FILENAME = N'D:\\MSSQL15.MSSQLSERVER\\MSSQL\DATA\ShrinkTest.mdf' , SIZE = 32481280KB , FILEGROWTH = 1024000KB )
 LOG ON 
( NAME = N'ShrinkTest_log', FILENAME = N'D:\\MSSQL15.MSSQLSERVER\\MSSQL\Log\ShrinkTest_log.ldf' , SIZE = 8192000KB , FILEGROWTH = 8192000KB )
GO

USE [master]
GO
ALTER DATABASE [ShrinkTest] ADD FILE ( NAME = N'ShrinkTest2', FILENAME = N'D:\\MSSQL15.MSSQLSERVER\\MSSQL\DATA\ShrinkTest2.ndf' , SIZE = 32481280KB , FILEGROWTH = 1024000KB ) TO FILEGROUP [PRIMARY]
GO

USE [master]
GO
ALTER DATABASE [ShrinkTest] ADD FILE ( NAME = N'ShrinkTest3', FILENAME = N'D:\\MSSQL15.MSSQLSERVER\\MSSQL\DATA\ShrinkTest3.ndf' , SIZE = 32481280KB , FILEGROWTH = 1024000KB ) TO FILEGROUP [PRIMARY]
GO

USE [master]
GO
ALTER DATABASE [ShrinkTest] ADD FILE ( NAME = N'ShrinkTest4', FILENAME = N'D:\\MSSQL15.MSSQLSERVER\\MSSQL\DATA\ShrinkTest4.ndf' , SIZE = 32481280KB , FILEGROWTH = 1024000KB ) TO FILEGROUP [PRIMARY]
GO

exec sp_helpdb 'ShrinkTest';

use ShrinkTest;

select *
into ShrinkTest.dbo.Posts
from StackOverflow.dbo.Posts

select *
into ShrinkTest.dbo.Users
from StackOverflow.dbo.Users

ALTER TABLE dbo.Posts
   ADD CONSTRAINT PK_Posts PRIMARY KEY CLUSTERED (Id);

ALTER TABLE dbo.Users
   ADD CONSTRAINT PK_Users PRIMARY KEY CLUSTERED (Id);

select top 10 * from dbo.Posts
select top 10 * from dbo.Users

ALTER TABLE dbo.Posts ADD CONSTRAINT fk_OwnerUserId FOREIGN KEY (OwnerUserId) REFERENCES dbo.Users(Id);

ALTER TABLE dbo.Posts ADD CONSTRAINT fk_ParentId FOREIGN KEY (ParentId) REFERENCES dbo.Posts(Id);

ALTER TABLE dbo.Users
   ADD CONSTRAINT chk_Users_age   
   CHECK (Age > 4);  
GO

create nonclustered index nci_Posts_OwnerUserId on dbo.Posts (OwnerUserId)
go

USE [master]
GO
ALTER DATABASE [ShrinkTest] ADD FILE ( NAME = N'ShrinkTest_2', FILENAME = N'F:\\MSSQL15.MSSQLSERVER\\Data\ShrinkTest_2.ndf' , SIZE = 32481280KB , FILEGROWTH = 1024000KB ) TO FILEGROUP [DATA]
GO

ALTER DATABASE [ShrinkTest] ADD FILE ( NAME = N'ShrinkTest_3', FILENAME = N'F:\\MSSQL15.MSSQLSERVER\\Data\ShrinkTest_3.ndf' , SIZE = 32481280KB , FILEGROWTH = 1024000KB ) TO FILEGROUP [DATA]
GO

ALTER DATABASE [ShrinkTest] ADD FILE ( NAME = N'ShrinkTest_4', FILENAME = N'F:\\MSSQL15.MSSQLSERVER\\Data\ShrinkTest_4.ndf' , SIZE = 32481280KB , FILEGROWTH = 1024000KB ) TO FILEGROUP [DATA]
GO

ALTER DATABASE [ShrinkTest] ADD FILE ( NAME = N'ShrinkTest_5', FILENAME = N'F:\\MSSQL15.MSSQLSERVER\\Data\ShrinkTest_5.ndf' , SIZE = 32481280KB , FILEGROWTH = 1024000KB ) TO FILEGROUP [DATA]
GO

USE [ShrinkTest]
GO
declare @autogrow bit
SELECT @autogrow=convert(bit, is_autogrow_all_files) FROM sys.filegroups WHERE name=N'DATA'
if(@autogrow=0)
	ALTER DATABASE [ShrinkTest] MODIFY FILEGROUP [DATA] AUTOGROW_ALL_FILES
GO
USE [master]
GO
declare @autogrow bit
SELECT @autogrow=convert(bit, is_autogrow_all_files) FROM sys.filegroups WHERE name=N'DATA'
if(@autogrow=0)
	ALTER DATABASE [ShrinkTest] MODIFY FILEGROUP [DATA] AUTOGROW_ALL_FILES
GO
USE [ShrinkTest]
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'DATA') ALTER DATABASE [ShrinkTest] MODIFY FILEGROUP [DATA] DEFAULT
GO
USE [ShrinkTest]
GO
ALTER AUTHORIZATION ON DATABASE::[ShrinkTest] TO [sa]
GO



/* Get Details of Object on different filegroup
Finding User Created Tables*/
SELECT o.[name], o.[type], i.[name], i.[index_id], f.[name] FROM sys.indexes i
INNER JOIN sys.filegroups f
ON i.data_space_id = f.data_space_id
INNER JOIN sys.all_objects o
ON i.[object_id] = o.[object_id] WHERE i.data_space_id = f.data_space_id
AND o.type = 'U' -- User Created Tables
GO

/*
name	type	name					index_id	name
Posts	U 		PK_Posts				1			PRIMARY
Posts	U 		nci_Posts_OwnerUserId	2			PRIMARY
Users	U 		PK_Users				1			PRIMARY
*/

-- Move non-clustered index
CREATE NONCLUSTERED INDEX [nci_Posts_OwnerUserId] ON [dbo].[Posts] ([OwnerUserId] ASC)
WITH (DROP_EXISTING = ON)  
ON DATA;  
GO

-- Move Clustered Index
CREATE UNIQUE CLUSTERED INDEX [PK_Posts] ON [dbo].[Posts] ([Id])  
WITH (DROP_EXISTING = ON)  
ON DATA
GO


