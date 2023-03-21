-- Conta o número de IDs de clientes únicos na tabela de clientes antiga
SELECT COUNT(*) AS 'Customers Amount' 
FROM WWI_OldData.dbo.Customer;
GO

-- Conta o número de IDs de clientes únicos na tabela de clientes atualizada
SELECT COUNT(*) AS 'Customers Amount'
FROM WWIGlobal.WWI.Customer;
GO

-- Conta o número de clientes em cada categoria, com nomes de categoria corrigidos e agrupados  - Dados antigos
WITH FixedCustomerData AS (
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
) SELECT
	Category AS 'Category Name',
    COUNT(*) AS 'Customers Amount' 
FROM FixedCustomerData 
GROUP BY 
    Category
ORDER BY 
    'Customers Amount' DESC;

-- Conta o número de clientes em cada categoria - Dados atualizados
SELECT 
	cusc.CustomerCategoryName as 'Category Name',
	Count(*) as 'Customers Amount'
FROM 
	WWIGlobal.WWI.Customer cus
INNER JOIN 
	WWIGlobal.WWI.CustomerCategory cusc on cus.CustomerCategoryID=cusc.CustomerCategoryID
GROUP BY cusc.CustomerCategoryName
ORDER BY 'Customers Amount' DESC;
GO

-- Conta o total de vendas realizadas por cada funcionário da empresa -> Dados Antigos
WITH FixedSaleData AS (
  SELECT
    DISTINCT
    [WWI Invoice ID], 
    [City Key], 
    [Salesperson Key],
    [Customer Key], 
    [Invoice Date Key], 
    [Delivery Date Key]
  FROM WWI_OldData.dbo.Sale
)
SELECT 
  emp.Employee as 'Employee', 
  COUNT(*) AS 'Total Sells'
FROM FixedSaleData fsd
INNER JOIN WWI_OldData.dbo.Employee emp 
  ON emp.[Employee Key] = fsd.[Salesperson Key]
INNER JOIN WWI_OldData.dbo.Customer cus
  ON fsd.[Customer Key] = cus.[Customer Key]
INNER JOIN WWI_OldData.dbo.City cit
  ON cit.[City Key] = fsd.[City Key]
GROUP BY emp.Employee
ORDER BY emp.Employee
GO

-- Conta o total de vendas realizadas por cada funcionário da empresa -> Dados atualizados
SELECT 
  emp.EmployeeName as 'Employee Name', 
  COUNT(ord.OrderID) as 'Total Sells' 
FROM 
  WWIGlobal.WWI.Employee emp
  INNER JOIN WWIGlobal.WWI.Orders ord
  ON emp.EmployeeID = ord.EmployeeID
GROUP BY 
  emp.EmployeeName
ORDER BY 
  emp.EmployeeName
GO


-- Total de vendas feitas por StockItem -> Dados Antigos
SELECT [Stock Item] as 'Product', [Unit Price], total as 'Amount Sales', (total * [Unit Price]) AS 'Total Value'
FROM (
    SELECT sti.[Stock Item], sti.[Unit Price], COUNT(*) as total
    FROM WWI_OldData.dbo.[Stock Item] sti	
    JOIN WWI_OldData.dbo.Sale sal ON sal.[Stock Item Key] = sti.[Stock Item Key]
    GROUP BY sti.[Stock Item], sti.[Unit Price]
) as cte
ORDER BY [Stock Item];
GO

-- Total de vendas feitas por StockItem -> Dados atualizados
SELECT ItemName as 'Product', unitprice as 'Unit Price', total as 'Amount Sales', (total * unitprice) AS 'Total Value'
FROM (
    SELECT sti.ItemName, sti.UnitPrice, COUNT(*) AS total
    FROM WWIGlobal.WWI.StockItem sti
    JOIN WWIGlobal.WWI.OrderList sai ON sai.StockItemID = sti.StockItemID
    GROUP BY sti.ItemName, sti.UnitPrice
) as cte
ORDER BY ItemName;
GO

-- Total de vendas anuais por Stock Item -> Dados Antigos
SELECT sti.[Stock Item]  AS 'Product', YEAR(sal.[Delivery Date Key]) as 'Year', count(*) as 'Amount Of Items', sti.[Unit Price] as 'Unit Price', (count(*)*sti.[Unit Price]) as 'Total Value' FROM WWI_OldData.dbo.[Stock Item] sti
JOIN WWI_OldData.DBO.Sale sal ON sal.[Stock Item Key] = sti.[Stock Item Key]
group by sti.[Stock Item], sti.[Unit Price], YEAR(sal.[Delivery Date Key]) 
order by sti.[Stock Item],  YEAR(sal.[Delivery Date Key])
GO

-- Total de vendas anuais por Stock Item -> Dados atualizados
SELECT sti.ItemName AS 'Product', YEAR(ord.InvoiceDate) as 'Year', count(*) as 'Amount Of Items', sti.UnitPrice as 'Unit Price', (count(*)*sti.UnitPrice) as 'Total Value' 
FROM WWIGlobal.WWI.StockItem sti
JOIN WWIGlobal.WWI.OrderList sai ON sai.StockItemID = sti.StockItemID
JOIN WWIGlobal.WWI.Orders ord ON ord.OrderID = sai.OrderID
GROUP BY sti.ItemName, sti.UnitPrice, YEAR(ord.InvoiceDate)
ORDER BY sti.ItemName, YEAR(ord.InvoiceDate)
GO

-- Total de Vendas anuais por cidade -> Dados Antigos
SELECT s.City, s.State, s.Year, SUM(s.[Total Price]) as 'Total Value'
FROM
(
	SELECT ct.City as 'City', ct.[State Province] as 'State', YEAR(sa.[Delivery Date Key]) as 'Year', count(*) as 'Amount', si.[Unit Price] as 'Unit Price' , (count(*)*(si.[Unit Price])) as 'Total Price' FROM WWI_OldData.dbo.[Stock Item] si
	JOIN WWI_OldData.DBO.Sale sa ON sa.[Stock Item Key] = si.[Stock Item Key] JOIN WWI_OldData.dbo.City ct ON sa.[City Key]=ct.[City Key]
	group by ct.[City], ct.[State Province], YEAR(sa.[Delivery Date Key]), si.[Unit Price]
) s
GROUP BY s.City, s.State, s.Year
ORDER BY s.City, s.State, s.Year
GO

-- Total de Vendas anuais por cidade -> Dados Atualizados
SELECT s.City, s.State, s.Year, SUM(s.[Total Price]) as 'Total Value'
FROM
(
	SELECT 
	ci.CityName as 'City', st.StateName as 'State', YEAR(ord.InvoiceDate) as 'Year', count(*) as 'Amount', si.UnitPrice as 'Unit Price' , (count(*)*(si.UnitPrice)) as 'Total Price'
	FROM WWIGlobal.WWI.StockItem si JOIN WWIGlobal.WWI.OrderList ol ON ol.StockItemID=si.StockItemID JOIN WWIGlobal.WWI.Orders ord ON ol.OrderID=ord.OrderID JOIN WWIGlobal.WWI.City ci on ci.CityID=ord.CityID JOIN WWIGlobal.WWI.State st ON ci.StateID= st.StateID
	group by ci.CityName, st.StateName, YEAR(ord.InvoiceDate), si.UnitPrice
) s
GROUP BY s.City, s.State, s.Year
ORDER BY s.City, s.State, s.Year
GO
