$nome = Read-Host "Digite o nome do servidor:"
if ($nome -eq "") {
    $nome = "$nome"
}

bcp "SELECT REPLACE((SELECT CustomerID, BillToCustomerID, BuyingGroupID, CustomerPrimaryContact, CustomerName, CustomerEmail, CustomerPassword, CustomerZipCode, CustomerIsHeadOffice, CustomerUpdateAt FROM WWIGlobal.WWI.Customer FOR JSON AUTO), CHAR(13) + CHAR(10), '')" queryout "./customer.json" -T -c -S $nome

bcp "SELECT REPLACE((SELECT OrderID, CustomerID, CityID, EmployeeID, CONVERT(nvarchar(20), InvoiceDate) AS InvoiceDate, CONVERT(nvarchar(20), OrderDate) AS OrderDate FROM WWIGlobal.WWI.Orders FOR JSON AUTO), CHAR(13) + CHAR(10), '')" queryout "./orders.json" -T -c -S $nome

bcp "SELECT REPLACE((SELECT OrderID, StockItemID, Quantity, UnitPrice FROM WWIGlobal.WWI.OrderList FOR JSON AUTO), CHAR(13) + CHAR(10), '')" queryout "./orderlist.json" -T -c -S $nome

bcp "SELECT REPLACE((SELECT StockItemID, ColorID, BrandID, SizeID, SellingPackageID, BuyingPackageID, ItemName, LeadTimeDays, QuantityPerOuter, IsChillerStock, BarCode, TaxRateID, UnitPrice, RecomendedRetailPrice, TypicalWeightPerUnit FROM WWIGlobal.WWI.StockItem FOR JSON AUTO), CHAR(13) + CHAR(10), '')" queryout "./stockitem.json" -T -c -S $nome

bcp "SELECT REPLACE((SELECT BrandID, BrandName FROM WWIGlobal.WWI.Brand FOR JSON AUTO), CHAR(13) + CHAR(10), '')" queryout "./brand.json" -T -c -S $nome

bcp "SELECT REPLACE((SELECT TaxRateID, TaxRate FROM WWIGlobal.WWI.TaxRate FOR JSON AUTO), CHAR(13) + CHAR(10), '')" queryout "./taxrate.json" -T -c -S $nome