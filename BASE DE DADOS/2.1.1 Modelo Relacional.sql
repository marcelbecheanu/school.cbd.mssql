-- Verifica se a base de dados 'WWIGlobal' existe antes de prosseguir com a exclusão.
IF DB_ID('WWIGlobal') IS NOT NULL
BEGIN
	USE MASTER;
	-- Interrompe imediatamente todas as conexões ativas.
	ALTER DATABASE WWIGlobal SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	-- Exclui a base de dados 'WWIGlobal'.
	DROP DATABASE WWIGlobal;
END
GO

-- Verifica se a base de dados 'WWIGlobal' não existe antes de prosseguir com a sua criação.
IF DB_ID('WWIGlobal') IS NULL EXECUTE('CREATE DATABASE WWIGlobal')
GO


USE WWIGlobal;
GO

-- O seguinte codigo sql foi utilizado para calcular os valores dos file groups.
-- Deve ser utilizado apôs a migração.

/*
BEGIN
	EXEC WWI.sp_monitoring
	select TableName, sum(MaxLength) from WWI.LastMonitoring
	group by TableName
	GO

	WITH Records AS (
		SELECT
			tab.name AS TableName,
			SUM(part.rows) AS NumRecords
		FROM sys.tables tab
		JOIN sys.partitions part ON tab.object_id = part.object_id
		WHERE tab.schema_id IN (SCHEMA_ID('WWI'), SCHEMA_ID('Logs')) AND part.index_id IN (0,1)
		GROUP BY tab.name
	), Usage AS (
		SELECT
			TableName,
			SUM(MaxLength) AS TotalMaxLength
		FROM WWI.LastMonitoring
		GROUP BY TableName
	)
	SELECT
		R.TableName,
		U.TotalMaxLength,
		R.NumRecords,
		R.NumRecords * U.TotalMaxLength AS TotalUsage
	FROM Records R
	JOIN Usage U ON R.TableName = U.TableName Order by R.TableName ASC
END
*/

-- Cria os FileGroups secundários.
ALTER DATABASE WWIGlobal
ADD FILEGROUP ReadDataGroup
GO

ALTER DATABASE WWIGlobal
ADD FILEGROUP WriteDataGroup
GO

-- Essencialmente Leitura de Dados.
ALTER DATABASE WWIGlobal ADD FILE (
	NAME = 'ReadDataGroup',
	FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\ReadDataFile.ndf',
	SIZE = 10MB,
	FILEGROWTH = 2MB
) TO FILEGROUP ReadDataGroup
GO

-- Essencialmente Escrita de Dados.
ALTER DATABASE WWIGlobal ADD FILE (
	NAME = 'WriteDataFile',
	FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\WriteDataFile.ndf',
	SIZE = 6MB,
	FILEGROWTH = 1MB
) TO FILEGROUP WriteDataGroup
GO

--  Verifica se o schema 'Logs' da base de dados 'WWIGlobal' não existe antes de prosseguir com a sua criação.
IF SCHEMA_ID('Logs') IS NULL EXECUTE('CREATE SCHEMA Logs');
GO

--  Verifica se o schema 'WWI' da base de dados 'WWIGlobal' não existe antes de prosseguir com a sua criação.
IF SCHEMA_ID('WWI') IS NULL EXECUTE('CREATE SCHEMA WWI');
GO



-- Verifique se as tabelas não existem antes de prosseguir com a criação.
-- Criação das tabelas responsáveis pelas localizações.
IF OBJECT_ID('WWI.Continent', 'U') IS NULL
	CREATE TABLE WWI.Continent (
			ContinentID INT NOT NULL IDENTITY(1, 1),
			ContinentName NVARCHAR(125) NOT NULL
			CONSTRAINT PK_Continent
				PRIMARY KEY (ContinentID),
			CONSTRAINT UQ_ContinentName
				UNIQUE (ContinentName),
	) ON ReadDataGroup;

IF OBJECT_ID('WWI.Country', 'U') IS NULL
	CREATE TABLE WWI.Country (
		CountryID INT NOT NULL IDENTITY(1, 1),
		ContinentID INT NOT NULL,
		CountryName NVARCHAR(125) NOT NULL,
		CONSTRAINT PK_Country
			PRIMARY KEY (CountryID),
		CONSTRAINT UQ_CountryName
			UNIQUE (CountryName),
		CONSTRAINT FK_ContinentCountry
			FOREIGN KEY (ContinentID)
			REFERENCES WWI.Continent(ContinentID)
	) ON ReadDataGroup;

IF OBJECT_ID('WWI.SalesTerritory', 'U') IS NULL
	CREATE TABLE WWI.SalesTerritory (
		SalesTerritoryID INT NOT NULL IDENTITY(1, 1),
		SalesTerritoryName NVARCHAR(125) NOT NULL
		CONSTRAINT PK_SalesTerritory
			PRIMARY KEY (SalesTerritoryID),
		CONSTRAINT UQ_SalesTerritoryName
			UNIQUE (SalesTerritoryName),
	) ON ReadDataGroup;

IF OBJECT_ID('WWI.State', 'U') IS NULL
	CREATE TABLE WWI.State (
		StateID INT NOT NULL IDENTITY(1, 1),
		CountryID INT NOT NULL,
		SalesTerritoryID INT NOT NULL,
		StateName NVARCHAR(60) NOT NULL,
		StateProvinceCode NVARCHAR(60) NOT NULL,
		CONSTRAINT PK_State
			PRIMARY KEY (StateID),
		CONSTRAINT UQ_StateName
			UNIQUE (StateName),
		CONSTRAINT UQ_StateProvinceCode
			UNIQUE (StateProvinceCode),
		CONSTRAINT FK_CountryState
			FOREIGN KEY (CountryID)
			REFERENCES WWI.Country(CountryID),
		CONSTRAINT FK_SalesTerritoryState
			FOREIGN KEY (SalesTerritoryID)
			REFERENCES WWI.SalesTerritory(SalesTerritoryID)
	) ON ReadDataGroup;


IF OBJECT_ID('WWI.City', 'U') IS NULL
	CREATE TABLE WWI.City (
		CityID INT NOT NULL IDENTITY(1, 1),
		StateID INT NOT NULL,
		CityName NVARCHAR(60) NOT NULL,
		LatestRecordedPopulation BIGINT NOT NULL DEFAULT 0,
		CONSTRAINT PK_City
			PRIMARY KEY (CityID),
		CONSTRAINT FK_StateCity
			FOREIGN KEY (StateID)
			REFERENCES WWI.State(StateID)
	) ON ReadDataGroup;


-- Verifique se as tabelas não existem antes de prosseguir com a criação.
-- Criação das tabelas responsáveis pela gestão dos 'customers'.
IF OBJECT_ID('WWI.CustomerCategory', 'U') IS NULL
	CREATE TABLE WWI.CustomerCategory (
		CustomerCategoryID INT NOT NULL IDENTITY(1, 1),
		CustomerCategoryName NVARCHAR(60) NOT NULL,
		CONSTRAINT PK_CustomerCategory
			PRIMARY KEY (CustomerCategoryID),
		CONSTRAINT UQ_CustomerCategoryName
			UNIQUE (CustomerCategoryName),
	) ON ReadDataGroup;

IF OBJECT_ID('WWI.BuyingGroup', 'U') IS NULL
	CREATE TABLE WWI.BuyingGroup (
		BuyingGroupID INT NOT NULL IDENTITY(1, 1),
		BuyingGroupName NVARCHAR(60) NOT NULL,
		CONSTRAINT PK_BuyingGroup
			PRIMARY KEY (BuyingGroupID),
		CONSTRAINT UQ_BuyingGroupName
			UNIQUE (BuyingGroupName),
	) ON ReadDataGroup;

IF OBJECT_ID('WWI.Customer', 'U') IS NULL
	CREATE TABLE WWI.Customer (
		CustomerID INT NOT NULL IDENTITY(1, 1),
		BillToCustomerID INT,
		CustomerCategoryID INT NOT NULL,
		BuyingGroupID int NOT NULL,
		CustomerPrimaryContact VARCHAR(125) NOT NULL,
		CustomerName NVARCHAR(125) NOT NULL,
		CustomerEmail NVARCHAR(256) NOT NULL UNIQUE,
		CustomerPassword NVARCHAR(255) NOT NULL,
		CustomerZipCode NVARCHAR(60) NOT NULL,
		CustomerIsHeadOffice BIT NOT NULL,
		CustomerUpdateAt DATETIME NOT NULL DEFAULT GETDATE()
		CONSTRAINT PK_Customer
			PRIMARY KEY (CustomerID),
		CONSTRAINT FK_CustomerID_BillToCustomerID
			FOREIGN KEY (BillToCustomerID)
			REFERENCES WWI.Customer(CustomerID),
		CONSTRAINT FK_CustomerCategoryCustomer
			FOREIGN KEY (CustomerCategoryID)
			REFERENCES WWI.CustomerCategory(CustomerCategoryID),
		CONSTRAINT FK_BuyingGroupCustomer
			FOREIGN KEY (BuyingGroupID)
			REFERENCES WWI.BuyingGroup(BuyingGroupID),
	) ON ReadDataGroup;

IF OBJECT_ID('WWI.Recovery', 'U') IS NULL
	CREATE TABLE WWI.Recovery (
		RecoveryID INT NOT NULL IDENTITY(1, 1),
		CustomerID INT NOT NULL,
		RecoveryToken NVARCHAR(60) NOT NULL,
		RecoveryCreateAt DATETIME NOT NULL DEFAULT GETDATE()
		CONSTRAINT PK_Recovery
			PRIMARY KEY (RecoveryID),
		CONSTRAINT FK_CustomerRecovery
			FOREIGN KEY (CustomerID)
			REFERENCES WWI.Customer(CustomerID),
	) ON WriteDataGroup;


-- Criação das tabelas responsáveis pelos produtos.
IF OBJECT_ID('WWI.Color', 'U') IS NULL
	CREATE TABLE WWI.Color (
		ColorID INT NOT NULL IDENTITY(1, 1),
		ColorName NVARCHAR(60) NOT NULL
		CONSTRAINT PK_Color
			PRIMARY KEY (ColorID),
		CONSTRAINT UQ_ColorName
			UNIQUE (ColorName),
	) ON ReadDataGroup;
	
IF OBJECT_ID('WWI.Brand', 'U') IS NULL
	CREATE TABLE WWI.Brand (
		BrandID INT NOT NULL IDENTITY(1, 1),
		BrandName NVARCHAR(60) NOT NULL
		CONSTRAINT PK_Brand
			PRIMARY KEY (BrandID),
		CONSTRAINT UQ_BrandName
			UNIQUE (BrandName),
	) ON ReadDataGroup;

		
IF OBJECT_ID('WWI.Size', 'U') IS NULL
	CREATE TABLE WWI.Size (
		SizeID INT NOT NULL IDENTITY(1, 1),
		SizeName NVARCHAR(60) NOT NULL
		CONSTRAINT PK_Size
			PRIMARY KEY (SizeID),
		CONSTRAINT UQ_SizeName
			UNIQUE (SizeName),
	) ON ReadDataGroup;
		
IF OBJECT_ID('WWI.Package', 'U') IS NULL
	CREATE TABLE WWI.Package (
		PackageID INT NOT NULL IDENTITY(1, 1),
		PackageName NVARCHAR(60) NOT NULL
		CONSTRAINT PK_Package
			PRIMARY KEY (PackageID),
		CONSTRAINT UQ_PackageName
			UNIQUE (PackageName),
	) ON ReadDataGroup;

IF OBJECT_ID('WWI.TaxRate', 'U') is NULL
	CREATE TABLE WWI.TaxRate (
		TaxRateID INT NOT NULL IDENTITY(1, 1),
		TaxRate DECIMAL(18,2) NOT NULL,
		CONSTRAINT PK_TaxRate
			PRIMARY KEY (TaxRateID),
		CONSTRAINT UQ_TaxRate
			UNIQUE (TaxRate)
	) ON ReadDataGroup;


IF OBJECT_ID('WWI.StockItem', 'U') IS NULL
	CREATE TABLE WWI.StockItem (
		StockItemID INT NOT NULL IDENTITY(1, 1),
		ColorID INT NOT NULL,
		BrandID INT NOT NULL,
		SizeID INT NOT NULL,
		SellingPackageID INT NOT NULL,
		BuyingPackageID INT NOT NULL,
		ItemName NVARCHAR(125) NOT NULL,
		LeadTimeDays INT NOT NULL,
		QuantityPerOuter INT NOT NULL,
		IsChillerStock bit NOT NULL,
		BarCode NVARCHAR(60) NOT NULL,
		TaxRateID INT NOT NULL,
		UnitPrice Decimal(18, 2) NOT NULL,
		RecomendedRetailPrice Decimal(18, 2) NOT NULL,
		TypicalWeightPerUnit Decimal(18, 3) NOT NULL,
		CONSTRAINT PK_StockItem
			PRIMARY KEY (StockItemID),
		CONSTRAINT FK_TaxRateStockItem
			FOREIGN KEY (TaxRateID)
			REFERENCES WWI.TaxRate(TaxRateID),
		CONSTRAINT FK_ColorStockItem
			FOREIGN KEY (ColorID)
			REFERENCES WWI.Color(ColorID),
		CONSTRAINT FK_BrandStockItem
			FOREIGN KEY (BrandID)
			REFERENCES WWI.Brand(BrandID),
		CONSTRAINT FK_SizeStockItem
			FOREIGN KEY (SizeID)
			REFERENCES WWI.Size(SizeID),
		CONSTRAINT FK_SellingPackageStockItem
			FOREIGN KEY (SellingPackageID)
			REFERENCES WWI.Package(PackageID),
		CONSTRAINT FK_BuyingPackageStockItem
			FOREIGN KEY (BuyingPackageID)
			REFERENCES WWI.Package(PackageID),
	) ON ReadDataGroup;


-- Criação das tabelas responsáveis pelas promoções.
IF OBJECT_ID('WWI.Promotion', 'U') IS NULL
	CREATE TABLE WWI.Promotion (
		PromotionID INT NOT NULL IDENTITY(1, 1),
		Description NVARCHAR(60) NOT NULL,
		Discount decimal(18, 3) NOT NULL,
		StartDate date NOT NULL,
		EndStart date NOT NULL,
		CONSTRAINT PK_Promotion
			PRIMARY KEY (PromotionID)
	) ON WriteDataGroup;

IF OBJECT_ID('WWI.PromotionGroup', 'U') IS NULL
	CREATE TABLE WWI.PromotionGroup (
		PromotionID INT NOT NULL,
		StockItemID INT NOT NULL UNIQUE,
		CONSTRAINT PK_PromotionGroup
			PRIMARY KEY (PromotionID, StockItemID),
		CONSTRAINT FK_PromotionPromotionGroup
			FOREIGN KEY (PromotionID)
			REFERENCES WWI.Promotion(PromotionID),
		CONSTRAINT FK_StockItemPromotionGroup
			FOREIGN KEY (StockItemID)
			REFERENCES WWI.StockItem(StockItemID),
	) ON WriteDataGroup;

-- Criação das tabelas responsáveis pelos pedidos.
IF OBJECT_ID('WWI.Employee', 'U') IS NULL
	CREATE TABLE WWI.Employee (
		EmployeeID INT NOT NULL IDENTITY(1, 1),
		EmployeeName NVARCHAR(125),
		EmployeePreferredName NVARCHAR(60),
		EmployeeIsSalesPerson BIT,
		EmployeePhoto NVARCHAR(260),
		CONSTRAINT PK_Employee
			PRIMARY KEY (EmployeeID)
	) ON ReadDataGroup;

IF OBJECT_ID('WWI.Orders', 'U') IS NULL
	CREATE TABLE WWI.Orders (
		OrderID INT NOT NULL IDENTITY(1, 1),
		CustomerID INT NOT NULL,
		EmployeeID INT NOT NULL,
		CityID INT NOT NULL,
		InvoiceID INT NOT NULL,
		OrderDate datetime NOT NULL DEFAULT GETDATE(),
		InvoiceDate datetime NULL
		CONSTRAINT PK_Order
			PRIMARY KEY (OrderID),
		CONSTRAINT FK_CustomerOrders
			FOREIGN KEY (CustomerID)
			REFERENCES WWI.Customer(CustomerID),
		CONSTRAINT FK_EmployeeOrders
			FOREIGN KEY (EmployeeID)
			REFERENCES WWI.Employee(EmployeeID),
		CONSTRAINT FK_CityOrders
			FOREIGN KEY (CityID)
			REFERENCES WWI.City(CityID),
	) ON WriteDataGroup;

IF OBJECT_ID('WWI.OrderList', 'U') IS NULL
	CREATE TABLE WWI.OrderList (
		OrderID INT NOT NULL,
		StockItemID INT NOT NULL,
		Quantity INT NOT NULL DEFAULT 1,
		UnitPrice Decimal(18, 2) NOT NULL,
		CONSTRAINT PK_OrderList
			PRIMARY KEY (OrderID, StockItemID),
		CONSTRAINT FK_OrdersOrderList
			FOREIGN KEY (OrderID)
			REFERENCES WWI.Orders(OrderID)
			ON DELETE CASCADE,
		CONSTRAINT FK_StockItemOrderList
			FOREIGN KEY (StockItemID)
			REFERENCES WWI.StockItem(StockItemID)
	) ON WriteDataGroup;
GO

-- Tratamento de erros.
-- Criação da tabela responsável pelo armazenamento dos erros.
IF OBJECT_ID('Logs.Error') IS NULL
	CREATE TABLE Logs.Error(
		ErrorID INT NOT NULL IDENTITY(1, 1),
		ErrorUserName NVARCHAR(100),
		ErrorNumber INT,
		ErrorState INT,
		ErrorSeverity INT,
		ErrorLine INT,
		ErrorProcedure NVARCHAR(MAX),
		ErrorMessage NVARCHAR(MAX),
		ErrorCreatedAt DATETIME,
		CONSTRAINT PK_Error
			PRIMARY KEY (ErrorID),
	) ON WriteDataGroup;
GO

-- Apoio à Monitorização
IF OBJECT_ID('WWI.Monitoring') IS NULL
	CREATE TABLE WWI.Monitoring(
		MonitoringID INT IDENTITY(1, 1),
		TableName NVARCHAR(255),
		ColumnName NVARCHAR(125),
		DataType NVARCHAR(125),
		MaxLength INT,
		IsNullable BIT,
		IsIdentity BIT,
		IsPrimaryKey BIT,
		CreatedAt DATETIME DEFAULT GETDATE(),
		CONSTRAINT PK_Monitoring
			PRIMARY KEY (MonitoringID)
	) ON WriteDataGroup;

IF OBJECT_ID('WWI.MonitoringStorage') IS NULL
	CREATE TABLE WWI.MonitoringStorage(
		MonitoringStorageID INT IDENTITY(1, 1),
		TableName NVARCHAR(255),
		ReservedSpace NVARCHAR(125),
		UsedSpace NVARCHAR(125),
		NumberOfRows NVARCHAR(125),
		CreatedAt DATETIME DEFAULT GETDATE(),
		CONSTRAINT PK_MonitoringStorage
			PRIMARY KEY (MonitoringStorageID)
	) ON WriteDataGroup;