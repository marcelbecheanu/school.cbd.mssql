USE master;
GO

---- Admin User
IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'Administrador')
BEGIN
    DROP LOGIN Administrador;
END

CREATE LOGIN Administrador WITH PASSWORD = 'Admin123456';
GO

USE WWIGlobal;
GO

IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'AdminUser')
BEGIN
    DROP USER AdminUser;
END
GO

CREATE USER AdminUser FOR LOGIN Administrador;
GO

ALTER ROLE [db_owner] ADD MEMBER AdminUser;
GO
------------------------------------------------------------------

-- EmployeeSalesPerson User
USE master;
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'EmployeeSalesPerson')
BEGIN
    DROP LOGIN EmployeeSalesPerson;
END
GO

CREATE LOGIN EmployeeSalesPerson WITH PASSWORD = 'EmployeeSalesPerson123456';
GO

USE WWIGlobal;
GO

IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'EmployeeSalesPersonUser')
BEGIN
    DROP USER EmployeeSalesPersonUser;
END
GO

CREATE USER EmployeeSalesPersonUser FOR LOGIN EmployeeSalesPerson;
GO

GRANT SELECT TO EmployeeSalesPersonUser;
GO

GRANT 
	SELECT,
	INSERT,
	UPDATE,
	DELETE
ON WWI.Orders
TO EmployeeSalesPersonUser;
GO

GRANT
	SELECT,
	INSERT,
	UPDATE,
	DELETE
ON WWI.OrderList
TO EmployeeSalesPersonUser;
GO
-----------------------------------------------------------------------------------------------------------------------

-- SalesTerritory User
USE master;
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'SalesTerritory')
BEGIN
    DROP LOGIN SalesTerritory;
END
GO

CREATE LOGIN SalesTerritory WITH PASSWORD = 'SalesTerritory123456';
GO

USE WWIGlobal;
GO

IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'SalesTerritoryUser')
BEGIN
    DROP USER SalesTerritoryUser;
END
GO

CREATE USER SalesTerritoryUser FOR LOGIN SalesTerritory;
GO

-- Sells in Rocky Mountain - Lista de Orders
CREATE OR ALTER VIEW WWI.SoldsInRockyMountain
AS
SELECT sty.SalesTerritoryName, ord.CustomerID, ord.EmployeeID,  ord.OrderDate, ord.InvoiceDate FROM WWI.Orders ord
JOIN WWI.City ci ON ord.CityID=ci.CityID
JOIN WWI.State st ON ci.StateID=st.StateID
JOIN WWI.SalesTerritory sty ON st.SalesTerritoryID=sty.SalesTerritoryID
WHERE sty.SalesTerritoryName='Rocky Mountain';
GO

-- List of Items in Sale in Rocky Mountain -- Lista de Itens da Order
CREATE OR ALTER VIEW WWI.SoldsItemsInRockyMountain
AS
SELECT sty.SalesTerritoryName, ord.OrderID, ord.CustomerID, ord.EmployeeID,  ord.OrderDate, ord.InvoiceID, ord.InvoiceDate, ol.StockItemID, ol.Quantity, ol.UnitPrice FROM WWI.Orders ord
JOIN WWI.OrderList ol ON ord.OrderID=ol.OrderID
JOIN WWI.City ci ON ord.CityID=ci.CityID
JOIN WWI.State st ON ci.StateID=st.StateID
JOIN WWI.SalesTerritory sty ON st.SalesTerritoryID=sty.SalesTerritoryID
WHERE sty.SalesTerritoryName='Rocky Mountain';
GO

GRANT
	SELECT
ON WWI.SoldsInRockyMountain
TO SalesTerritoryUser;

GRANT
	SELECT
ON WWI.SoldsItemsInRockyMountain
TO SalesTerritoryUser;
GO

-- Testes

-- Testes Relativos Ao Administrador.
EXECUTE AS USER = 'AdminUser' 
GO

IF IS_MEMBER('db_owner') = 1
BEGIN
	PRINT 'AdminUser - Has permissions.'
END
ELSE
BEGIN
   PRINT 'AdminUser - Not has permissions.'
END

REVERT -- Voltar ao user anterior
GO

-- Testes Relativos ao EmployeeSalesPerson

EXECUTE AS USER = 'EmployeeSalesPersonUser'
GO

INSERT INTO WWI.City(StateID, CityName, LatestRecordedPopulation)
VALUES(1, 'TESTE', 0)
GO -- Não deve permitir

SELECT * FROM WWI.City; -- Deve Permitir

INSERT INTO WWI.Orders(CityID, CustomerID, EmployeeID, InvoiceID) VALUES (1, 1, 1, 2321234) -- DEVE PERMITIR
INSERT INTO WWI.OrderList(OrderID, Quantity, StockItemID, UnitPrice) VALUES(
(SELECT OrderID FROM WWI.Orders WHERE OrderDate=(SELECT MAX(OrderDate) FROM WWI.Orders))
, 1, 1, 12); -- DEVE PERMITIR

SELECT * FROM WWI.Orders where OrderID=(SELECT OrderID FROM WWI.Orders WHERE OrderDate=(SELECT MAX(OrderDate) FROM WWI.Orders)) -- DEVE PERMITIR
SELECT * FROM WWI.OrderList where OrderID=(SELECT OrderID FROM WWI.Orders WHERE OrderDate=(SELECT MAX(OrderDate) FROM WWI.Orders)) -- DEVE PERMITIR

REVERT -- Voltar ao user anterior
GO

-- Testes Relativos ao SalesTerritory
EXECUTE AS USER = 'SalesTerritoryUser'

SELECT * FROM WWI.Orders; -- Não deve permitir
SELECT * FROM WWI.Brand; -- Não deve permitir
SELECT * FROM WWI.Color; -- Não deve permitir

SELECT * FROM WWI.SoldsInRockyMountain; -- DEVE PERMITIR
SELECT * FROM WWI.SoldsItemsInRockyMountain; -- DEVE PERMITIR

REVERT -- Voltar ao user anterior
GO



