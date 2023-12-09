-------------------------------------------------------------------------------
-- Simplification
-------------------------------------------------------------------------------

-- Get estimated execution plan on these two queries. Note that the optimizer makes 
-- the same plan for them because the subquery in the first is re-written as an 
-- INNER JOIN (as in query 2).
SELECT oh.OrderId, oh.OrderDate, oh.CustomerId
FROM CorpDB.dbo.OrderHeader oh
WHERE oh.CustomerId IN
	(
		SELECT c.CustomerId
		FROM CorpDB.dbo.Customer c
		WHERE c.State = 'NE'
	)
OPTION (RECOMPILE, QUERYTRACEON 8605, QUERYTRACEON 8606);

-- Another subquery to INNER JOIN
-- Note how the "simplified" tree treats the query as if it had been written without 
-- the subquery.
-- MAXDOP 1 specified to simplify the graphical query plan, but works without MAXDOP 
-- as well.
SELECT CustomerOrderView.OrderId, CustomerOrderView.CustomerId, od.ProductId
FROM CorpDB.dbo.OrderDetail od
	INNER JOIN
	(
		SELECT oh.OrderId, oh.CustomerId, c.State
		FROM CorpDB.dbo.OrderHeader oh
		INNER JOIN CorpDB.dbo.Customer c on oh.CustomerId = c.CustomerId
	) CustomerOrderView on od.OrderId = CustomerOrderView.OrderId
WHERE CustomerOrderView.State = 'NE'
OPTION (MAXDOP 1, RECOMPILE, QUERYTRACEON 8605, QUERYTRACEON 8606);

-- Predicate pushdown
-- Note that the select logical operation (LogOp_Select) is pushed below the join
SELECT oh.OrderId, oh.OrderDate, oh.CustomerId
FROM CorpDB.dbo.OrderHeader oh
	INNER JOIN CorpDB.dbo.Customer c on oh.CustomerId = c.CustomerID
WHERE c.State = 'NE'
OPTION (RECOMPILE, QUERYTRACEON 8605, QUERYTRACEON 8606);

-- Contradiction detection: 
-- Get an estimated plan on this query.
-- Note that we need to include a JOIN in the query to avoid getting a trivial plan.
-- SQL Server recognizes that the WHERE conditions are contradictory and removes all 
-- data access.
SELECT p.ProductId, p.ProductName, p.UnitPrice
FROM CorpDB.dbo.Product p
	INNER JOIN CorpDB.dbo.OrderDetail od on od.ProductId = p.ProductId
WHERE p.UnitPrice > 50.00
	AND p.UnitPrice < 25.00;
GO

-- Foreign key table removal:
-- Get an estimated query plan on this query. Note that SQL removes the Customer 
-- table entirely from the plan because the FK guarantees that the row exists in 
-- Customer, and no columns are otherwise required from Customer.
SELECT oh.OrderId, oh.OrderDate, oh.CustomerId
FROM CorpDB.dbo.OrderHeader oh
	INNER JOIN CorpDB.dbo.Customer c on oh.CustomerId = c.CustomerID;

-- We temporarily disable the FK.
ALTER TABLE CorpDB.dbo.OrderHeader NOCHECK CONSTRAINT fk_OrderHeader__Customer;

-- Get the estimated plan again. Now it MUST actually access the Customer table.
SELECT oh.OrderId, oh.OrderDate, oh.CustomerId
FROM CorpDB.dbo.OrderHeader oh
	INNER JOIN CorpDB.dbo.Customer c on oh.CustomerId = c.CustomerID;

-- Re-enable the FK.
ALTER TABLE CorpDB.dbo.OrderHeader CHECK CONSTRAINT fk_OrderHeader__Customer;

-- Get the estimated plan again.
-- SQL Server knows that there may have been changes to OrderHeader that don't 
-- comply with the FK, so Customer will still be accessed.
SELECT oh.OrderId, oh.OrderDate, oh.CustomerId
FROM CorpDB.dbo.OrderHeader oh
	INNER JOIN CorpDB.dbo.Customer c on oh.CustomerId = c.CustomerID;

-- Enable the FK and validate the data.
ALTER TABLE CorpDB.dbo.OrderHeader WITH CHECK CHECK CONSTRAINT fk_OrderHeader__Customer;

-- Get the estimated plan again. As before, SQL Server is now satisfied of data 
-- integrity and once again skip physical access to Customer table.
SELECT oh.OrderId, oh.OrderDate, oh.CustomerId
FROM CorpDB.dbo.OrderHeader oh
	INNER JOIN CorpDB.dbo.Customer c on oh.CustomerId = c.CustomerID;

