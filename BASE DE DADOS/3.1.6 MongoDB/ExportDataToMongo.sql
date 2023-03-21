USE WWIGlobal;
GO

-- DECRYPT DATA.
-- Abrir a chave simetrica.
OPEN SYMMETRIC KEY WWIGlobalKey DECRYPTION
BY CERTIFICATE WWIGlobalCert
GO

-- Read Decrypt data.
UPDATE WWIGlobal.WWI.StockItem SET [UnitPrice] = CONVERT(varbinary, decryptbykey([UnitPrice]));
GO

-- Change type of column
ALTER TABLE WWI.StockItem
ALTER Column [UnitPrice] decimal(18,2)
GO

-- Fechar Chave simetrica
CLOSE SYMMETRIC KEY WWIGlobalKey;
GO

SELECT * FROM WWI.StockItem;
GO

------------------------------------------------------------------


-- Migrate Customers
SELECT REPLACE((SELECT CustomerID, BillToCustomerID, BuyingGroupID, CustomerPrimaryContact, CustomerName, CustomerEmail, CustomerPassword, CustomerZipCode, CustomerIsHeadOffice, CustomerUpdateAt FROM WWIGlobal.WWI.Customer FOR JSON AUTO), CHAR(13) + CHAR(10), '')
GO

-- Migrate Orders Query
SELECT REPLACE((SELECT OrderID, CustomerID, CityID, EmployeeID, CONVERT(nvarchar(20), InvoiceDate) AS InvoiceDate, CONVERT(nvarchar(20), OrderDate) AS OrderDate FROM WWIGlobal.WWI.Orders FOR JSON AUTO), CHAR(13) + CHAR(10), '')
GO

-- Migrate OrderList Query
SELECT REPLACE((SELECT OrderID, StockItemID, Quantity, UnitPrice FROM WWIGlobal.WWI.OrderList FOR JSON AUTO), CHAR(13) + CHAR(10), '')
GO

-- Migrate StockItem
SELECT REPLACE((SELECT StockItemID, ColorID, BrandID, SizeID, SellingPackageID, BuyingPackageID, ItemName, LeadTimeDays, QuantityPerOuter, IsChillerStock, BarCode, TaxRateID, UnitPrice, RecomendedRetailPrice, TypicalWeightPerUnit FROM WWIGlobal.WWI.StockItem FOR JSON AUTO), CHAR(13) + CHAR(10), '')
GO

-- Migrate Brand
SELECT REPLACE((SELECT BrandID, BrandName FROM WWIGlobal.WWI.Brand FOR JSON AUTO), CHAR(13) + CHAR(10), '')
GO

-- Migrate TaxRate
SELECT REPLACE((SELECT TaxRateID, TaxRate FROM WWIGlobal.WWI.TaxRate FOR JSON AUTO), CHAR(13) + CHAR(10), '')
GO


-- PowerShell Commands -- TROCAR O NAME SERVER
-- Também em alternativa é possivel executar o ficheiro ps1.
-- Apos preencher deve voltar a encriptar a base de dados.

-- bcp "SELECT REPLACE((SELECT CustomerID, BillToCustomerID, BuyingGroupID, CustomerPrimaryContact, CustomerName, CustomerEmail, CustomerPassword, CustomerZipCode, CustomerIsHeadOffice, CustomerUpdateAt FROM WWIGlobal.WWI.Customer FOR JSON AUTO), CHAR(13) + CHAR(10), '')" queryout "./customer.json" -T -c -S MARCELPC

-- bcp "SELECT REPLACE((SELECT OrderID, CustomerID, CityID, EmployeeID, CONVERT(nvarchar(20), InvoiceDate) AS InvoiceDate, CONVERT(nvarchar(20), OrderDate) AS OrderDate FROM WWIGlobal.WWI.Orders FOR JSON AUTO), CHAR(13) + CHAR(10), '')" queryout "./orders.json" -T -c -S MARCELPC

-- bcp "SELECT REPLACE((SELECT OrderID, StockItemID, Quantity, UnitPrice FROM WWIGlobal.WWI.OrderList FOR JSON AUTO), CHAR(13) + CHAR(10), '')" queryout "./orderlist.json" -T -c -S MARCELPC

-- bcp "SELECT REPLACE((SELECT StockItemID, ColorID, BrandID, SizeID, SellingPackageID, BuyingPackageID, ItemName, LeadTimeDays, QuantityPerOuter, IsChillerStock, BarCode, TaxRateID, UnitPrice, RecomendedRetailPrice, TypicalWeightPerUnit FROM WWIGlobal.WWI.StockItem FOR JSON AUTO), CHAR(13) + CHAR(10), '')" queryout "./stockitem.json" -T -c -S MARCELPC

-- bcp "SELECT REPLACE((SELECT BrandID, BrandName FROM WWIGlobal.WWI.Brand FOR JSON AUTO), CHAR(13) + CHAR(10), '')" queryout "./brand.json" -T -c -S MARCELPC

-- bcp "SELECT REPLACE((SELECT TaxRateID, TaxRate FROM WWIGlobal.WWI.TaxRate FOR JSON AUTO), CHAR(13) + CHAR(10), '')" queryout "./taxrate.json" -T -c -S MARCELPC


-- Codigo para encriptar novamente
-- Adicionar Coluna que vai armazenar os dados encryptados
ALTER TABLE WWI.StockItem
ALTER Column [UnitPrice] VARBINARY(256)
GO

-- Abrir a chave simetrica.
OPEN SYMMETRIC KEY WWIGlobalKey DECRYPTION
BY CERTIFICATE WWIGlobalCert
GO

-- Atualizando a coluna com os dados encriptados. 
UPDATE WWI.StockItem SET [UnitPrice] = ENCRYPTBYKEY(KEY_GUID('WWIGlobalKey'), UnitPrice)
GO

-- Read Decrypt data.
SELECT *, CONVERT(DECIMAL(18, 2), CONVERT(varbinary, decryptbykey([UnitPrice]))) AS DecryptedUnitPrice FROM WWIGlobal.WWI.StockItem
GO

-- Fechar Chave simetrica
CLOSE SYMMETRIC KEY WWIGlobalKey;
GO
