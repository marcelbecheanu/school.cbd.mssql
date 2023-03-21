USE WWIGlobal;
GO

-- Vendas por cidade: nome da cidade, nome do vendedor e total de vendas (cidades distintas com o mesmo nome);
CREATE OR ALTER VIEW WWI.VW_OrdersByCity
AS
SELECT EmployeeName AS 'Employee', CityName AS 'City', StateName as 'State', COUNT(*) as 'Sales Amount'
FROM WWI.Orders ord
JOIN WWI.City ci on ord.CityID=ci.CityID
JOIN WWI.State st on ci.StateID=st.StateID
JOIN WWI.Employee em on em.EmployeeID=ord.EmployeeID
GROUP BY EmployeeName, CityName, StateName
GO

-- Consulta Antiga
CREATE OR ALTER VIEW WWI.VW_OrdersByCityOld
AS
SELECT Employee AS 'Employee', City AS 'City', [State Province] as 'State', COUNT(*) as 'Sales Amount'
FROM (SELECT DISTINCT [Customer Key], [Salesperson Key], [City Key], [WWI Invoice ID], [Invoice Date Key], [Delivery Date Key]  FROM WWI_OldData.dbo.Sale sal) sal
JOIN WWI_OldData.dbo.Employee emp ON sal.[Salesperson Key]=emp.[Employee Key]
JOIN WWI_OldData.dbo.City cit on sal.[City Key]=cit.[City Key]
GROUP BY Employee, City, [State Province]
GO


-- Para as vendas calcular a taxa de crescimento de cada ano, face ao ano anterior, por categoria de cliente;
CREATE OR ALTER VIEW WWI.VW_OrdersGrowthByCategory
AS
SELECT 
	*,
	(
		CASE WHEN T.[Sales Amount (Previous Year)] <= 0
		THEN T.[Sales Amount]
		ELSE ROUND((CAST((T.[Sales Amount] - T.[Sales Amount (Previous Year)]) AS float) / T.[Sales Amount (Previous Year)]) * 100, 2)
		END
	) AS 'Growth Rate (%)'
FROM (
	SELECT cc.CustomerCategoryName as 'Category', YEAR(ord.InvoiceDate)  as 'Year', 
		COUNT(*) AS 'Sales Amount',
		YEAR(ord.InvoiceDate) - 1 as 'Previous Year',  
		(
			 SELECT COUNT(*) 
			 FROM WWI.Orders ord2
			 JOIN WWI.Customer cu2 ON ord2.CustomerID=cu2.CustomerID
			 JOIN WWI.CustomerCategory cc2 ON cu2.CustomerCategoryID=cc2.CustomerCategoryID
			 WHERE cc2.CustomerCategoryID = cc.CustomerCategoryID AND YEAR(ord2.InvoiceDate) = YEAR(ord.InvoiceDate) - 1
		) AS 'Sales Amount (Previous Year)'
	FROM WWI.Orders ord
	JOIN WWI.Customer cu ON ord.CustomerID=cu.CustomerID
	JOIN WWI.CustomerCategory cc ON cu.CustomerCategoryID=cc.CustomerCategoryID
	WHERE ord.InvoiceDate IS NOT NULL
	GROUP BY cc.CustomerCategoryID, cc.CustomerCategoryName,  YEAR(ord.InvoiceDate), YEAR(ord.InvoiceDate) - 1
) AS T
GO

-- Consulta Antiga
CREATE OR ALTER VIEW WWI.VW_OrdersGrowthByCategoryOld
AS
WITH FixedCustomerCategoryData as (
	SELECT
		[Customer Key],
		[WWI Customer ID],
		Customer,
		[Bill To Customer],
		CASE 
			WHEN Category = 'Quiosk' THEN 'Kiosk' 
			WHEN Category = 'GiftShop' THEN 'Gift Shop' 
			ELSE Category 
		END AS Category,
		[Buying Group], 
		[Primary Contact],
		[Postal Code]
		FROM WWI_OldData.dbo.Customer
) 
SELECT
*,
(
		CASE WHEN datatemp2.[previoussalesamount] <= 0
		THEN datatemp2.[salesAmount]
		ELSE ROUND((CAST((datatemp2.[salesAmount] - datatemp2.[previoussalesamount] ) AS float) / datatemp2.[previoussalesamount]) * 100, 2)
		END
) AS 'Growth Rate (%)'
FROM (
	SELECT DATATEMP.Category AS CAT, DATATEMP.[Year] as NewYear, DATATEMP.[Previous Year] as PreviousYear, SUM(DATATEMP.[Sales Amount]) as salesAmount, SUM(DATATEMP.[Sales Amount (Previous Year)]) as previoussalesamount FROM (
		SELECT
			fccd.Category as 'Category',	
			YEAR(sal.[Delivery Date Key])  as 'Year',
			YEAR(sal.[Delivery Date Key]) - 1 as 'Previous Year',
			COUNT(*) AS 'Sales Amount',
			(
				SELECT COUNT(*) FROM (SELECT DISTINCT [Customer Key], [Salesperson Key], [City Key], [WWI Invoice ID], [Invoice Date Key], [Delivery Date Key]  FROM WWI_OldData.dbo.Sale sal) sal2
				JOIN FixedCustomerCategoryData fccd2 on sal2.[Customer Key]=fccd2.[Customer Key]
				WHERE fccd2.[Customer Key]=fccd.[Customer Key] AND YEAR(sal2.[Delivery Date Key]) = YEAR(sal.[Delivery Date Key]) - 1
				GROUP BY fccd2.Category, YEAR(sal2.[Delivery Date Key])
			) AS 'Sales Amount (Previous Year)'
		FROM FixedCustomerCategoryData fccd 
		JOIN (SELECT DISTINCT [Customer Key], [Salesperson Key], [City Key], [WWI Invoice ID], [Invoice Date Key], [Delivery Date Key]  FROM WWI_OldData.dbo.Sale sal) sal ON sal.[Customer Key]=fccd.[Customer Key]
		WHERE sal.[Delivery Date Key] IS NOT NULL
		GROUP BY fccd.[Customer Key], fccd.Category, YEAR(sal.[Delivery Date Key]), YEAR(sal.[Delivery Date Key]) - 1
		) AS DATATEMP
	GROUP BY DATATEMP.Category, DATATEMP.[Year], DATATEMP.[Previous Year]
	) AS datatemp2
GO


-- Nº de produtos (stockItem) nas vendas por cor.
CREATE OR ALTER VIEW WWI.VW_ProductsOrdersByColor
AS
SELECT co.ColorName AS 'Color', COUNT(si.StockItemID) as 'Products Sold'
FROM WWI.OrderList orl 
JOIN WWI.StockItem si ON orl.StockItemID=si.StockItemID
JOIN WWI.Color co on si.ColorID=co.ColorID
GROUP BY co.ColorName
GO

-- Nº de produtos (stockItem) nas vendas por cor.
CREATE OR ALTER VIEW WWI.VW_ProductsOrdersByColorOld
AS
SELECT sti.Color AS 'Color', COUNT(sti.[Stock Item Key]) as 'Products Sold' FROM WWI_OldData.dbo.[Stock Item] sti
JOIN WWI_OldData.dbo.Sale sal ON sti.[Stock Item Key]=sal.[Stock Item Key]
GROUP BY sti.Color
GO



SET STATISTICS IO ON
GO

SELECT * FROM WWI.VW_OrdersByCity ORDER BY Employee, City, State
GO

SELECT * FROM WWI.VW_OrdersByCityOld ORDER BY Employee, City, State
GO

SELECT * FROM WWI.VW_OrdersGrowthByCategory ORDER BY 'Category', 'Previous Year'
GO

SELECT * FROM WWI.VW_OrdersGrowthByCategoryOld ORDER BY CAT, PreviousYear
GO

SELECT * FROM WWI.VW_ProductsOrdersByColor ORDER BY 'Products Sold' ASC;
GO

SELECT * FROM WWI.VW_ProductsOrdersByColorOld ORDER BY 'Products Sold' ASC;
GO

SET STATISTICS IO OFF
GO

-- Para a primeira consulta:
-- Este índice inclui as colunas usadas na cláusula JOIN para recuperar as informações da cidade e do funcionário, bem como a coluna OrderID, que é usada na junção com a tabela OrderList.
CREATE NONCLUSTERED INDEX IDX_Orders_City_Employee_OrderID ON WWI.Orders(CityID, EmployeeID) INCLUDE (OrderID)

-- Para a segunda consulta:
-- O primeiro índice inclui a coluna InvoiceDate, que é usada na cláusula WHERE para filtrar os pedidos por ano. Também inclui a coluna CustomerID, que é usada na junção com a tabela Customer.
-- O segundo índice inclui a coluna CustomerCategoryID, que é usada na cláusula GROUP BY.
CREATE NONCLUSTERED INDEX IDX_Orders_InvoiceDate ON WWI.Orders(InvoiceDate, CustomerID) INCLUDE (OrderID)
CREATE NONCLUSTERED INDEX IDX_Customer_Orders ON WWI.CustomerCategory (CustomerCategoryID) INCLUDE (CustomerCategoryName)

-- Para a terceira consulta:
-- O primeiro índice inclui a coluna StockItemID, que é usada na junção com a tabela StockItem. O segundo índice inclui a coluna ColorID, que é usada na junção com a tabela Color.
-- Ambos os índices incluem as colunas usadas na cláusula SELECT e GROUP BY.
CREATE NONCLUSTERED INDEX IDX_OrderList_StockItem ON WWI.OrderList (StockItemID) INCLUDE (OrderID)
CREATE NONCLUSTERED INDEX IDX_StockItem_Color ON WWI.StockItem (ColorID) INCLUDE (StockItemID)
