USE AdventureWorks2014;
GO

-- Setup
CREATE TABLE ProductCategory
(
     CategoryID INT Primary Key,
     CategoryName VARCHAR(50)
);
CREATE TABLE Product
(
     ProductID INT Primary Key,
     ProductName VARCHAR(100),
     QtyInStock INT,
     CategoryID VARCHAR(10)
) ;
INSERT INTO ProductCategory (CategoryID, CategoryName)
VALUES (1, 'Ale'),
(2, 'Lager'),
(3, 'Pilsner'),
(4, 'Stout'),
(5, 'N/A')
;
INSERT INTO Product (ProductID, ProductName, QtyInStock, CategoryID)
VALUES (1, 'Spotted Cow', 8966, '1'),
(2, 'Fat Squirrel', 7643, '1'),
(3, 'Moon Man', 339, '1'),
(4, 'Two Women', 1224, '2'),
(5, 'Home Town Blonde', 564, '2'),
(6, 'Ginger Ale', 899, '5')
;

-- Implicit conversion in FROM clauses
DECLARE @Category INT
SELECT @Category = 2

SELECT PC.CategoryName,
     P.ProductID,
     P.ProductName
FROM ProductCategory PC
     INNER JOIN Product P ON P.CategoryID = PC.CategoryID
WHERE PC.CategoryID = @Category;

SELECT PC.CategoryName,
     P.ProductID,
     P.ProductName
FROM ProductCategory PC
     INNER JOIN Product P ON P.CategoryID  = CAST(PC.CategoryID AS INT)
WHERE PC.CategoryID = @Category;


-- Implicit conversion in WHERE clauses
DECLARE @Category INT
SELECT @Category = 1

SELECT P.ProductName,
     P.QtyInStock
FROM Product P
WHERE P.CategoryID = @Category;
GO

DECLARE @Category VARCHAR(10)
SELECT @Category = '1'

SELECT P.ProductName,
     P.QtyInStock
FROM Product P
WHERE P.CategoryID = @Category;
GO

--Both
DECLARE @Category VARCHAR(10)
SELECT @Category = '1'

SELECT PC.CategoryName,
P.ProductID,
P.ProductName
FROM ProductCategory PC
INNER JOIN Product P ON P.CategoryID = PC.CategoryID
WHERE PC.CategoryID = @Category;

--And
SELECT PC.CategoryName,
P.ProductID,
P.ProductName
FROM ProductCategory PC
INNER JOIN Product P ON P.CategoryID = CAST(PC.CategoryID AS INT)
WHERE PC.CategoryID = @Category;
GO

--End up converting PC.CategoryID to an int before making the comparison. So why does it matter to the compiler?

--Second:
--In the case of

SELECT PC.CategoryName,
P.ProductID,
P.ProductName
FROM ProductCategory PC
INNER JOIN Product P ON P.CategoryID = PC.CategoryID
WHERE PC.CategoryID = @Category;

-- It appears that the copy of PC.CategoryID being converted is the one in the WHERE clause. And in fact when I removed 
-- that line I no longer saw the term “CONVERT_IMPLICIT”. So then I tried doing my CAST on the version in the WHERE clause 
-- and again didn’t see CONVERT_IMPLICIT but I do see CONVERT instead (which I didn’t see when the convert is in the ON clause). Can you explain?


-- Cleanup
DROP TABLE ProductCategory;
DROP TABLE Product;

-- AdventureWorks2014 Example
USE AdventureWorks2014
GO

SELECT BusinessEntityID, NationalIDNumber, LoginID
FROM HumanResources.Employee
WHERE NationalIDNumber = 112457891;
GO

SELECT BusinessEntityID, NationalIDNumber, LoginID
FROM HumanResources.Employee
WHERE NationalIDNumber = '112457891'
GO

SELECT BusinessEntityID, NationalIDNumber, LoginID
FROM HumanResources.Employee
WHERE NationalIDNumber = N'112457891'
GO