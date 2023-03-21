
-- Database data migration --
EXEC sp_configure 'show advanced option', '1';
RECONFIGURE;

EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;

USE WWIGlobal;
GO

-- Copies all colors that do not exist in the table.
BEGIN
	INSERT INTO WWI.Color(ColorName) SELECT Data.Color as ColorName
	FROM 
		OPENROWSET('Microsoft.ACE.OLEDB.12.0',
			'Excel 12.0; Database=C:\Users\Marce\Desktop\NEW DATABASE\InitialData\lookup.xlsx', [Color$]) Data 
END
GO
 
-- Copies all categories that do not exist in the table.
BEGIN
	INSERT INTO WWI.CustomerCategory(CustomerCategoryName) SELECT
		(CASE Data.Name 
			WHEN 'Kiosk ' THEN 'Kiosk' 
			ELSE Data.Name 
		END) as CustomerCategoryName
	FROM 
		OPENROWSET('Microsoft.ACE.OLEDB.12.0',
			'Excel 12.0; Database=C:\Users\Marce\Desktop\NEW DATABASE\InitialData\lookup.xlsx', [Category$]) Data
END
GO

-- Copies all Packages that do not exist in the table.
BEGIN
	INSERT INTO WWI.Package(PackageName) SELECT Data.Package as PackageName
	FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
		'Excel 12.0; Database=C:\Users\Marce\Desktop\NEW DATABASE\InitialData\lookup.xlsx', [Package$]) Data 
END
GO

BEGIN
	DECLARE @City NVARCHAR(60);
	DECLARE @State NVARCHAR(60);
	DECLARE @Country NVARCHAR(60);
	DECLARE @Continent NVARCHAR(60);
	DECLARE @SalesTerritory NVARCHAR(60);
	DECLARE @PopulationRecords BIGINT;

	-- This is a temp Table to load data from file.
	DECLARE @TempState Table(code nvarchar(10), StateName nvarchar(100))
	INSERT INTO @TempState(code, StateName) SELECT
							SUBSTRING(data.F1, 1, CHARINDEX(';', data.F1) - 1) as Code,
							SUBSTRING(data.F1, CHARINDEX(';', data.F1) + 1, LEN(data.F1)) as StateName 
							FROM (SELECT * FROM OPENROWSET(
							'Microsoft.ACE.OLEDB.12.0',
							'Text;Database=C:\Users\Marce\Desktop\NEW DATABASE\InitialData\; HDR=NO; FORMAT=Delimited(;)',
							'SELECT * FROM states.txt')) data WHERE data.F1 != 'Code;Name';

	DECLARE Cities CURSOR FOR 
		SELECT DISTINCT [City], [State Province], [Country], [Continent], [Sales Territory], [Latest Recorded Population] FROM WWI_OldData.dbo.City;
	
	OPEN Cities
		FETCH NEXT FROM Cities INTO @City, @State, @Country, @Continent, @SalesTerritory, @PopulationRecords
			WHILE @@FETCH_STATUS = 0
			BEGIN  
				PRINT 'ROW DATA: ' + @CITY + ', ' + @State + ', ' + @Country + ', ' + @Continent + ', ' + @SalesTerritory;
				
				/* INSERT CONTINENT */
				INSERT INTO WWIGlobal.WWI.Continent(ContinentName) SELECT @Continent WHERE NOT EXISTS(SELECT * FROM WWIGlobal.WWI.Continent WHERE ContinentName = @Continent); 

				/* INSERT Country */
				INSERT INTO WWIGlobal.WWI.Country(ContinentID, CountryName) SELECT (SELECT C.ContinentID FROM WWIGlobal.WWI.Continent C WHERE C.ContinentName = @Continent), @Country WHERE NOT EXISTS(SELECT * FROM WWIGlobal.WWI.Country WHERE CountryName = @Country);

				/* INSERT Sales */
				INSERT INTO WWIGlobal.WWI.SalesTerritory(SalesTerritoryName) SELECT @SalesTerritory WHERE NOT EXISTS(SELECT * FROM WWIGlobal.WWI.SalesTerritory WHERE SalesTerritoryName = @SalesTerritory);

				/* INSERT States */
				SET @State = (SELECT TS.StateName FROM @TempState TS WHERE @State LIKE  TS.StateName + '%');
				INSERT INTO WWIGlobal.WWI.State(CountryID, SalesTerritoryID, StateName, StateProvinceCode) SELECT
					(SELECT CountryID FROM WWIGlobal.WWI.Country WHERE CountryName=@Country),
					(SELECT SalesTerritoryID FROM WWIGlobal.WWI.SalesTerritory WHERE SalesTerritoryName=@SalesTerritory),
					(@State),
					(SELECT code FROM @TempState WHERE StateName=@State)
				WHERE NOT EXISTS (
					SELECT * FROM WWIGlobal.WWI.State WHERE StateName=@State
				)
				
				/* INSERT CITY */
				INSERT INTO WWIGlobal.WWI.City(StateID, CityName, LatestRecordedPopulation) SELECT 
					(SELECT StateID from WWIGlobal.WWI.State WHERE StateName=@State),
					(@City),
					(@PopulationRecords)
				WHERE NOT EXISTS (
					SELECT * FROM WWIGlobal.WWI.City WHERE CityName=@City AND StateID=(SELECT StateID from WWIGlobal.WWI.State WHERE StateName=@State)
				)

				FETCH NEXT FROM Cities INTO @City, @State, @Country, @Continent, @SalesTerritory, @PopulationRecords
			END 
	CLOSE Cities
	DEALLOCATE Cities
END
GO


-- MIGRATE CUSTOMER DATE
BEGIN
	-- MIGRATE BUYINGGROUP
	INSERT INTO WWIGlobal.WWI.BuyingGroup(BuyingGroupName) SELECT 
	DISTINCT [Buying Group]
	FROM [WWI_OldData].[dbo].[Customer] OldCustomer;

	-- MIGRATE CUSTOMER
	-- MIGRATE FIRST CUSTOMER HEAD OFFICE
	INSERT INTO WWIGlobal.WWI.Customer(
		BillToCustomerID,
		CustomerCategoryID,
		BuyingGroupID,
		CustomerName,
		CustomerEmail,
		CustomerPassword,
		CustomerZipCode,
		CustomerIsHeadOffice,
		CustomerPrimaryContact
	) SELECT
		NULL as BillToCustomerID,
		(SELECT CustomerCategoryID FROM WWI.CustomerCategory WHERE CustomerCategoryName like OldCustomer.Category COLLATE Latin1_General_100_CI_AS) as CustomerCategoryID ,
		(SELECT BuyingGroupID FROM WWIGlobal.WWI.BuyingGroup WHERE BuyingGroupName like OldCustomer.[Buying Group] COLLATE Latin1_General_100_CI_AS) as BuyingGroupID,
		OldCustomer.Customer as CustomerName,
		CONCAT(CONVERT(varchar(256), NEWID()),'@gmail.com') as CustomerEmail,
		WWI.fnEncryptPassword(CONVERT(varchar(255), NEWID())) as CustomerPassword,
		OldCustomer.[Postal Code] as CustomerZipCode,
		(CASE WHEN CHARINDEX('Head Office', Customer) > 0 THEN 1 ELSE 0 END) as CustomerIsHeadOffice,
		OldCustomer.[Primary Contact]
	FROM (
		SELECT
		  [Customer Key],
		  [WWI Customer ID],
		  [Customer],
		  [Bill To Customer],
			CASE [Category] 
				WHEN 'GiftShop' THEN 'Gift Shop' 
				WHEN 'Quiosk' THEN 'Kiosk' 
				WHEN 'Kiosk ' THEN 'Kiosk' 
				ELSE [Category] 
			END as [Category], 
		  [Buying Group],
		  [Primary Contact],
		  [Postal Code],
		  (CASE WHEN CHARINDEX('Head Office', Customer) > 0 THEN 1 ELSE 0 END) as isHeadOffice
		FROM WWI_OldData.dbo.Customer
	) OldCustomer Where CHARINDEX('Head Office', Customer) > 0 Order BY OldCustomer.isHeadOffice DESC;

	-- Atualiza o BillToCustomer
	UPDATE WWIGlobal.WWI.Customer SET BillToCustomerID=CustomerID WHERE CHARINDEX('Head Office', CustomerName) > 0

	-- Insere o resto dos customers
	INSERT INTO WWIGlobal.WWI.Customer(
		BillToCustomerID,
		CustomerCategoryID,
		BuyingGroupID,
		CustomerName,
		CustomerEmail,
		CustomerPassword,
		CustomerZipCode,
		CustomerIsHeadOffice,
		CustomerPrimaryContact
	) SELECT
		(SELECT CustomerID FROM WWIGlobal.WWI.Customer WHERE CustomerName Like oldCustomer.[Bill To Customer] COLLATE Latin1_General_100_CI_AS) AS BillToCustomerID,
		(SELECT CustomerCategoryID FROM WWI.CustomerCategory WHERE CustomerCategoryName like OldCustomer.Category COLLATE Latin1_General_100_CI_AS) as CustomerCategoryID ,
		(SELECT BuyingGroupID FROM WWIGlobal.WWI.BuyingGroup WHERE BuyingGroupName like OldCustomer.[Buying Group] COLLATE Latin1_General_100_CI_AS) as BuyingGroupID,
		OldCustomer.Customer as CustomerName,
		CONCAT(CONVERT(varchar(256), NEWID()),'@gmail.com') as CustomerEmail,
		WWI.fnEncryptPassword(CONVERT(varchar(255), NEWID())) as CustomerPassword,
		OldCustomer.[Postal Code] as CustomerZipCode,
		(CASE WHEN CHARINDEX('Head Office', Customer) > 0 THEN 1 ELSE 0 END) as CustomerIsHeadOffice,
		OldCustomer.[Primary Contact]
	FROM (
		SELECT
		  [Customer Key],
		  [WWI Customer ID],
		  [Customer],
		  [Bill To Customer],
			CASE [Category] 
				WHEN 'GiftShop' THEN 'Gift Shop' 
				WHEN 'Quiosk' THEN 'Kiosk' 
				WHEN 'Kiosk ' THEN 'Kiosk' 
				ELSE [Category] 
			END as [Category], 
		  [Buying Group],
		  [Primary Contact],
		  [Postal Code],
		  (CASE WHEN CHARINDEX('Head Office', Customer) > 0 THEN 1 ELSE 0 END) as isHeadOffice
		FROM WWI_OldData.dbo.Customer
	) OldCustomer WHERE CHARINDEX('Head Office', Customer) < 1 ORDER BY OldCustomer.isHeadOffice DESC;


	/*
	INSERT INTO WWIGlobal.WWI.Customer(
		BillToCustomerID,
		CustomerCategoryID,
		BuyingGroupID,
		CustomerName,
		CustomerEmail,
		CustomerPassword,
		CustomerZipCode,
		CustomerIsHeadOffice,
		CustomerPrimaryContact
	) SELECT
		CASE WHEN OldCustomer.Customer COLLATE Latin1_General_100_CI_AS LIKE OldCustomer.[Bill To Customer] COLLATE Latin1_General_100_CI_AS
			THEN OldCustomer.[Customer Key]
			ELSE (
				SELECT [Customer Key] FROM WWI_OldData.dbo.Customer WHERE Customer Like OldCustomer.[Bill To Customer] AND CHARINDEX('Head Office', Customer) > 0
			)
		END as BillToCustomerID,
		(SELECT CustomerCategoryID FROM WWI.CustomerCategory WHERE CustomerCategoryName like OldCustomer.Category COLLATE Latin1_General_100_CI_AS) as CustomerCategoryID ,
		(SELECT BuyingGroupID FROM WWIGlobal.WWI.BuyingGroup WHERE BuyingGroupName like OldCustomer.[Buying Group] COLLATE Latin1_General_100_CI_AS) as BuyingGroupID,
		OldCustomer.Customer as CustomerName,
		CONCAT(CONVERT(varchar(256), NEWID()),'@gmail.com') as CustomerEmail,
		WWI.fnEncryptPassword(CONVERT(varchar(255), NEWID())) as CustomerPassword,
		OldCustomer.[Postal Code] as CustomerZipCode,
		(CASE WHEN CHARINDEX('Head Office', Customer) > 0 THEN 1 ELSE 0 END) as CustomerIsHeadOffice,
		OldCustomer.[Primary Contact]
	FROM (
		SELECT
		  [Customer Key],
		  [WWI Customer ID],
		  [Customer],
		  [Bill To Customer],
			CASE [Category] 
				WHEN 'GiftShop' THEN 'Gift Shop' 
				WHEN 'Quiosk' THEN 'Kiosk' 
				WHEN 'Kiosk ' THEN 'Kiosk' 
				ELSE [Category] 
			END as [Category], 
		  [Buying Group],
		  [Primary Contact],
		  [Postal Code],
		  (CASE WHEN CHARINDEX('Head Office', Customer) > 0 THEN 1 ELSE 0 END) as isHeadOffice
		FROM WWI_OldData.dbo.Customer
	) OldCustomer ORDER BY OldCustomer.isHeadOffice DESC;*/
END
GO

-- Migrate Employee
BEGIN
	INSERT INTO WWIGlobal.WWI.Employee(EmployeeName, EmployeePreferredName, EmployeeIsSalesPerson, EmployeePhoto)
		SELECT DISTINCT
			em.[Employee],
			em.[Preferred Name],
			em.[Is Salesperson],
			NULL
		FROM WWI_OldData.dbo.Employee as em;
END
GO

-- Migrate Stock Item
BEGIN
	-- MIGRATE BRANDS
	INSERT INTO WWIGlobal.WWI.Brand(BrandName)
		SELECT DISTINCT br.Brand
		FROM  WWI_OldData.dbo.[Stock Item] br;

	-- MIGRADE SIZES
	INSERT INTO WWIGlobal.WWI.Size(SizeName)
		SELECT DISTINCT si.Size
		FROM WWI_OldData.dbo.[Stock Item] si;

	-- MIGRATE TAX RATE
	INSERT INTO WWIGlobal.WWI.TaxRate(TaxRate)
        SELECT DISTINCT si.[Tax Rate]
		FROM WWI_OldData.dbo.[Stock Item] si

	-- MIGRATE STOCK ITEM
	INSERT INTO WWIGlobal.WWI.StockItem(
		ColorID,
		BrandID,
		SizeID,
		SellingPackageID,
		BuyingPackageID,
		ItemName,
		LeadTimeDays,
		QuantityPerOuter,
		IsChillerStock,
		BarCode,
		TaxRateID,
		UnitPrice,
		RecomendedRetailPrice,
		TypicalWeightPerUnit
	) SELECT DISTINCT
		(SELECT co.ColorID FROM WWIGlobal.WWI.Color co WHERE co.ColorName like si.Color COLLATE Latin1_General_100_CI_AS) as ColorID,
		(SELECT br.BrandID FROM WWIGlobal.WWI.Brand br where br.BrandName like si.Brand COLLATE Latin1_General_100_CI_AS) as BrandID,
		(SELECT sz.SizeID FROM WWIGlobal.WWI.Size sz WHERE sz.SizeName like si.Size COLLATE Latin1_General_100_CI_AS) as SizeID,
		(SELECT pa.PackageID FROM WWIGlobal.WWI.Package pa WHERE pa.PackageName like si.[Selling Package] COLLATE Latin1_General_100_CI_AS) as SellinngPackageID,
		(SELECT pa.PackageID FROM WWIGlobal.WWI.Package pa WHERE pa.PackageName like si.[Buying Package] COLLATE Latin1_General_100_CI_AS) as BuyingPackageID,
		si.[Stock Item],
		si.[Lead Time Days],
		si.[Quantity Per Outer],
		si.[Is Chiller Stock],
		si.[Barcode],
		(SELECT ta.TaxRateID FROM WWIGlobal.WWI.TaxRate ta WHERE ta.TaxRate=si.[Tax Rate]) as TaxRate,
		si.[Unit Price],
		si.[Recommended Retail Price],
		si.[Typical Weight Per Unit]
	FROM WWI_OldData.dbo.[Stock Item] si;
END
GO

-- MIGRATE ORDERS
BEGIN
	INSERT INTO WWIGlobal.WWI.Orders(CustomerID, EmployeeID, CityID, InvoiceID, OrderDate, InvoiceDate)
		SELECT DISTINCT
			(
				SELECT NewCustomer.CustomerID as NewKey FROM
				WWIGlobal.WWI.Customer as NewCustomer,
				(SELECT
					  [Customer Key],
					  [WWI Customer ID],
					  [Customer],
					  [Bill To Customer],
						CASE [Category] 
							WHEN 'GiftShop' THEN 'Gift Shop' 
							WHEN 'Quiosk' THEN 'Kiosk' 
							WHEN 'Kiosk ' THEN 'Kiosk' 
							ELSE [Category] 
						END as [Category], 
					  [Buying Group],
					  [Primary Contact],
					  [Postal Code],
					  (CASE WHEN CHARINDEX('Head Office', Customer) > 0 THEN 1 ELSE 0 END) as isHeadOffice
					FROM WWI_OldData.dbo.Customer) as OldCustomer
				WHERE
					NewCustomer.CustomerName Like  OldCustomer.Customer COLLATE Latin1_General_100_CI_AS AND
					NewCustomer.CustomerCategoryID = (SELECT CustomerCategoryID FROM WWI.CustomerCategory WHERE CustomerCategoryName like OldCustomer.Category COLLATE Latin1_General_100_CI_AS) AND
					NewCustomer.BuyingGroupID = (SELECT BuyingGroupID FROM WWIGlobal.WWI.BuyingGroup WHERE BuyingGroupName like OldCustomer.[Buying Group] COLLATE Latin1_General_100_CI_AS) AND 
					NewCustomer.CustomerZipCode = OldCustomer.[Postal Code] COLLATE Latin1_General_100_CI_AS AND
					OldCustomer.[Customer Key]=sl.[Customer Key] 
			) as CustomerID,
			(
				SELECT EmployeeID
				FROM
					WWIGlobal.WWI.Employee as NewEmployee, WWI_OldData.dbo.Employee as OldEmployee
				WHERE
					NewEmployee.EmployeeName like OldEmployee.Employee COLLATE Latin1_General_100_CI_AS AND
					NewEmployee.EmployeePreferredName like OldEmployee.[Preferred Name] COLLATE Latin1_General_100_CI_AS AND
					NewEmployee.EmployeeIsSalesPerson like OldEmployee.[Is Salesperson] AND
					OldEmployee.[Employee Key] = sl.[Salesperson Key]
			) as EmployeeID,
			(
				SELECT NewCity.CityID
				FROM WWIGlobal.WWI.City NewCity, WWI_OldData.dbo.City OldCity
				WHERE
					NewCity.CityName LIKE OldCity.City COLLATE Latin1_General_100_CI_AS AND
					NewCity.StateID = (SELECT StateID FROM WWIGlobal.WWI.State WHERE OldCity.[State Province] LIKE StateName+'%'  COLLATE Latin1_General_100_CI_AS) AND
					OldCity.[City Key]=sl.[City Key]
			) as CityID,
			sl.[WWI Invoice ID],
			sl.[Invoice Date Key],
			sl.[Delivery Date Key]
		FROM WWI_OldData.dbo.Sale as sl;
END
GO

CREATE OR ALTER VIEW WWI.temp_data AS
	SELECT
		NewStockItem.StockItemID as NewItemID,
		sl.[WWI Invoice ID] as InvoiceID,
		OldStockItem.[Stock Item Key] as OldItemID,
		NewStockItem.ItemName as ItemName,
		sl.Quantity as 'Quantity',
		sl.[Invoice Date Key],
		sl.[Delivery Date Key],
		sl.[Unit Price]
	FROM
		(
			SELECT
				si.[Stock Item Key],
				(SELECT co.ColorID FROM WWIGlobal.WWI.Color co WHERE co.ColorName like si.Color COLLATE Latin1_General_100_CI_AS) as ColorID,
				(SELECT br.BrandID FROM WWIGlobal.WWI.Brand br where br.BrandName like si.Brand COLLATE Latin1_General_100_CI_AS) as BrandID,
				(SELECT sz.SizeID FROM WWIGlobal.WWI.Size sz WHERE sz.SizeName like si.Size COLLATE Latin1_General_100_CI_AS) as SizeID,
				(SELECT pa.PackageID FROM WWIGlobal.WWI.Package pa WHERE pa.PackageName like si.[Selling Package] COLLATE Latin1_General_100_CI_AS) as SellinngPackageID,
				(SELECT pa.PackageID FROM WWIGlobal.WWI.Package pa WHERE pa.PackageName like si.[Buying Package] COLLATE Latin1_General_100_CI_AS) as BuyingPackageID,
				si.[Stock Item],
				si.[Lead Time Days],
				si.[Quantity Per Outer],
				si.[Is Chiller Stock],
				si.[Barcode],
				(SELECT ta.TaxRateID FROM WWIGlobal.WWI.TaxRate ta WHERE ta.TaxRate=si.[Tax Rate]) as TaxRate,
				si.[Unit Price],
				si.[Recommended Retail Price],
				si.[Typical Weight Per Unit]
			FROM WWI_OldData.dbo.[Stock Item] si
		) as OldStockItem,
		WWIGlobal.WWI.StockItem as NewStockItem,
		WWI_OldData.dbo.Sale as sl
	WHERE
		OldStockItem.[Stock Item] LIKE NewStockItem.ItemName COLLATE Latin1_General_100_CI_AS AND
		OldStockItem.ColorID = NewStockItem.ColorID AND
		OldStockItem.BrandID = NewStockItem.BrandID AND
		OldStockItem.SizeID = NewStockItem.SizeID AND
		OldStockItem.SellinngPackageID = NewStockItem.SellingPackageID AND
		OldStockItem.BuyingPackageID = NewStockItem.BuyingPackageID AND
		OldStockItem.[Unit Price] = NewStockItem.UnitPrice AND
		sl.[Stock Item Key] = OldStockItem.[Stock Item Key]
GO

INSERT INTO WWIGlobal.WWI.OrderList(OrderID, StockItemID, Quantity, UnitPrice)
SELECT OrderID, NewItemID, Quantity, [Unit Price] FROM (SELECT
	(
		SELECT NewCustomer.CustomerID as NewKey FROM
		WWIGlobal.WWI.Customer as NewCustomer,
		(
		SELECT
				[Customer Key],
				[WWI Customer ID],
				[Customer],
				[Bill To Customer],
				CASE [Category] 
					WHEN 'GiftShop' THEN 'Gift Shop' 
					WHEN 'Quiosk' THEN 'Kiosk' 
					WHEN 'Kiosk ' THEN 'Kiosk' 
					ELSE [Category] 
				END as [Category], 
				[Buying Group],
				[Primary Contact],
				[Postal Code],
				(CASE WHEN CHARINDEX('Head Office', Customer) > 0 THEN 1 ELSE 0 END) as isHeadOffice
			FROM WWI_OldData.dbo.Customer) as OldCustomer
		WHERE
			NewCustomer.CustomerName Like  OldCustomer.Customer COLLATE Latin1_General_100_CI_AS AND
			NewCustomer.CustomerCategoryID = (SELECT CustomerCategoryID FROM WWI.CustomerCategory WHERE CustomerCategoryName like OldCustomer.Category COLLATE Latin1_General_100_CI_AS) AND
			NewCustomer.BuyingGroupID = (SELECT BuyingGroupID FROM WWIGlobal.WWI.BuyingGroup WHERE BuyingGroupName like OldCustomer.[Buying Group] COLLATE Latin1_General_100_CI_AS) AND 
			NewCustomer.CustomerZipCode = OldCustomer.[Postal Code] COLLATE Latin1_General_100_CI_AS AND
			OldCustomer.[Customer Key]=sl.[Customer Key] 
	) as CustomerID,
	[WWI Invoice ID],
	[Stock Item Key]
FROM WWI_OldData.dbo.Sale AS sl) as t JOIN WWI.temp_data as td ON td.OldItemID=t.[Stock Item Key] AND td.InvoiceID=t.[WWI Invoice ID] JOIN WWIGlobal.WWI.Orders as ob ON ob.CustomerID=t.CustomerID AND ob.InvoiceID=t.[WWI Invoice ID]


-- DELETE VIEW
DROP VIEW  WWI.temp_data;