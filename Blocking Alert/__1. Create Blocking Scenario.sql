-- Create database for Demo
CREATE DATABASE BlockingDemo
GO

USE [BlockingDemo]
GO

-- Create table
CREATE TABLE dbo.tblBlckScenario
(	ID INT IDENTITY(1,1) NOT NULL,
	Name varchar(50) NOT NULL,
	Salary INT NOT NULL
);
GO

-- Populate Data
INSERT dbo.tblBlckScenario
	(Name, Salary)
SELECT	'Ajay', 30000
UNION
SELECT	'Vijay', 22000
UNION
SELECT	'Sanjeev', 150000
UNION
SELECT	'Frank', 50000
UNION
SELECT	'Anant', 40000
GO

-- Session 1
USE [BlockingDemo]
GO
BEGIN TRAN
	-- Increate Salary by 10%
	UPDATE dbo.tblBlckScenario
	SET Salary = Salary + (Salary*0.10)


-- Session 2
/*
USE [BlockingDemo]
GO
SELECT * FROM dbo.tblBlckScenario;
*/