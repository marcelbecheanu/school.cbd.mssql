USE WWIGlobal;
GO

-- Verifica se a chave simétrica existe antes de excluí-la
IF EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = 'WWIGlobalKey')
	DROP SYMMETRIC KEY WWIGlobalKey;
GO

-- Verifica se o certificado existe antes de excluí-lo
IF EXISTS (SELECT * FROM sys.certificates WHERE name = 'WWIGlobalCert')
	DROP CERTIFICATE WWIGlobalCert;
GO

-- Verifica se a Master Key existe antes de excluí-la
IF EXISTS (SELECT * FROM sys.symmetric_keys WHERE name LIKE '%DatabaseMasterKey%')
	DROP MASTER KEY;
GO

-- Criação da Master Key
CREATE MASTER KEY ENCRYPTION
BY PASSWORD = 'WWIGlobal2023'
GO

-- Criação do Certificado de Encriptação.
CREATE CERTIFICATE WWIGlobalCert
WITH SUBJECT = 'Protect Data'
GO

-- Criação da Chave Simetrica.
CREATE SYMMETRIC KEY WWIGlobalKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE WWIGlobalCert;
GO

-- Encriptação dos dados usando a chave e o certificado gerado 

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


-- Estás funções são correções de algumas funções da programação devido a encriptação.
-- calcula o preço total de uma venda -- 
CREATE or ALTER FUNCTION WWI.fn_calculateOrderTotal
(
	@OrderID INT
) returns DECIMAL(18,3) AS
BEGIN
	
	DECLARE @DecryptedStockItems TABLE (
		StockItemID INT,
		ColorID INT,
		BrandID INT,
		SizeID INT,
		SellingPackageID INT,
		BuyingPackageID INT,
		ItemName NVARCHAR(100),
		LeadTimeDays INT,
		QuantityPerOuter INT,
		IsChillerStock BIT,
		BarCode VARCHAR(50),
		TaxRateID INT,
		UnitPrice DECIMAL(18, 2),
		RecomendedRetailPrice DECIMAL(18, 2),
		TypicalWeightPerUnit DECIMAL(18, 2)
	);

	-- Select decrypted data.
	INSERT INTO @DecryptedStockItems
	SELECT 
		StockItemID,
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
		CONVERT(DECIMAL(18, 2), CONVERT(varbinary, decryptbykey([UnitPrice]))) as UnitPrice,
		RecomendedRetailPrice,
		TypicalWeightPerUnit
	FROM WWIGlobal.WWI.StockItem;

	-- Declaração de uma variável para armazenar o preço total calculado.
	DECLARE @TotalPrice DECIMAL(18, 3) = 0.000;

	-- Utilização de uma instrução SELECT para calcular a soma do preço total de todos os itens na encomenda, tendo em conta a taxa.
	SELECT @TotalPrice = SUM((ol.Quantity * ol.UnitPrice) * (1 + tr.TaxRate / 100))
	FROM WWI.OrderList ol
	JOIN @DecryptedStockItems si ON si.StockItemID = ol.StockItemID
	JOIN WWI.TaxRate tr ON tr.TaxRateID = si.TaxRateID
	WHERE ol.OrderID = @OrderID;
  
	-- Retorna o preço total.
	RETURN @TotalPrice
END
GO

-- Retorna o tempo de atraso de uma encomenda.
CREATE OR ALTER FUNCTION WWI.fn_CheckOrderLeadTime(@orderID INT)
RETURNS INT AS
BEGIN

	DECLARE @DecryptedStockItems TABLE (
		StockItemID INT,
		ColorID INT,
		BrandID INT,
		SizeID INT,
		SellingPackageID INT,
		BuyingPackageID INT,
		ItemName NVARCHAR(100),
		LeadTimeDays INT,
		QuantityPerOuter INT,
		IsChillerStock BIT,
		BarCode VARCHAR(50),
		TaxRateID INT,
		UnitPrice DECIMAL(18, 2),
		RecomendedRetailPrice DECIMAL(18, 2),
		TypicalWeightPerUnit DECIMAL(18, 2)
	);

	-- Select decrypted data.
	INSERT INTO @DecryptedStockItems
	SELECT 
		StockItemID,
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
		CONVERT(DECIMAL(18, 2), CONVERT(varbinary, decryptbykey([UnitPrice]))) as UnitPrice,
		RecomendedRetailPrice,
		TypicalWeightPerUnit
	FROM WWIGlobal.WWI.StockItem;
	
	DECLARE @orderToInvoiceDays INT, @maxLeadTime INT;

	-- Obter o número de dias entre a data de encomenda e a data da fatura
	SELECT @orderToInvoiceDays = DATEDIFF(DAY, ord.OrderDate, ord.InvoiceDate)
	FROM WWI.Orders ord
	WHERE ord.OrderID = @orderID;

	-- Obter o tempo máximo de leadtime para o pedido (O maior de tempo de todos os itens)
	SELECT @maxLeadTime = MAX(si.LeadTimeDays)
	FROM WWI.OrderList ol
	JOIN WWI.StockItem si ON ol.StockItemID = si.StockItemID
	WHERE ol.OrderID = @orderID;

	-- Verificar se o tempo entre a encomenda e a fatura é inferior ao tempo máximo de leadtime
	IF (@orderToInvoiceDays < @maxLeadTime)
		SET @orderToInvoiceDays = 0;

	RETURN @orderToInvoiceDays;
END
GO


-- TRIGGER Verifica se a encomenda se encontra no prazo.
-- Este Trigger será executado após a atualização da tabela
CREATE OR ALTER TRIGGER WWI.tr_OrderDeliveryStatus
ON WWI.Orders
AFTER UPDATE
AS BEGIN

	-- Verificar se a coluna InvoiceDate foi atualizada
	IF UPDATE(InvoiceDate)
	BEGIN
		DECLARE @currentOrderID INT, @leadTime INT;
		
		OPEN SYMMETRIC KEY WWIGlobalKey DECRYPTION
		BY CERTIFICATE WWIGlobalCert

		-- Obter o ID da encomenda atual e o tempo de espera, que é retornado pela função fn_CheckOrderLeadTime.
		-- A função retorna 0 se a encomenda não estiver atrasada, caso contrário, retorna o número de dias de atraso.
		SELECT @currentOrderID = OrderID, @leadTime = WWI.fn_CheckOrderLeadTime(OrderID)
		FROM INSERTED;
			
		CLOSE SYMMETRIC KEY WWIGlobalKey;
		

		-- Imprimir uma mensagem indicando se a encomenda está atrasada ou não e informa os dias de atraso.
		IF @leadTime > 0
			PRINT 'Order is delayed by ' + CONVERT(NVARCHAR(256), @leadTime) + ' days.';
		ELSE
			PRINT 'The order is not delayed.';
	END
END
GO

-- TRIGGER - Verifica se uma venda contém apenas produtos com "Chiller Stock" ou apenas produtos sem "Chiller Stock".
-- Aplica também o desconto de promoção.
CREATE OR ALTER TRIGGER WWI.tr_OrderValidationAndDiscounts
ON WWI.OrderList
FOR INSERT, UPDATE
AS
BEGIN

	-- Declaração de variáveis
	DECLARE @StockItemID INT;
	DECLARE @OrderID INT;
	SELECT @StockItemID = StockItemID, @OrderID = OrderID FROM inserted;

	-- Verifica se o item inserido é um "Chiller Stock"
	DECLARE @InsertItemIsChiller BIT = (SELECT IsChillerStock FROM StockItem where StockItemID=@StockItemID);
	
	-- Verifica se a Order contém itens com "Chiller Stock"
	DECLARE @OrderChiller BIT = CASE WHEN (SELECT Count(*) FROM WWI.OrderList ol JOIN WWI.StockItem si on ol.StockItemID=si.StockItemID WHERE ol.OrderID=@OrderID AND si.IsChillerStock=1) > 0 THEN 1 ELSE 0 END;
	
	-- Verifica se a Order não contém itens "Chiller Stock"
	DECLARE @OrderNotChiller BIT = CASE WHEN (SELECT Count(*) FROM WWI.OrderList ol JOIN WWI.StockItem si on ol.StockItemID=si.StockItemID WHERE ol.OrderID=@OrderID AND si.IsChillerStock=0) > 0 THEN 1 ELSE 0 END;

	-- Verifica se a Order contém mistura de itens com e sem "Chiller Stock"
	IF (@InsertItemIsChiller = 0 AND @OrderChiller = 1) OR (@InsertItemIsChiller = 1 AND @OrderNotChiller = 1)
	BEGIN
		-- Exibe mensagem de erro e desfaz a transação
		RAISERROR('Only chiller products or only non-chiller products are allowed in the same order.', 16, 1);
		ROLLBACK TRANSACTION;  
		RETURN;
	END

	OPEN SYMMETRIC KEY WWIGlobalKey DECRYPTION
	BY CERTIFICATE WWIGlobalCert

	DECLARE @DecryptedStockItems TABLE (
		StockItemID INT,
		ColorID INT,
		BrandID INT,
		SizeID INT,
		SellingPackageID INT,
		BuyingPackageID INT,
		ItemName NVARCHAR(100),
		LeadTimeDays INT,
		QuantityPerOuter INT,
		IsChillerStock BIT,
		BarCode VARCHAR(50),
		TaxRateID INT,
		UnitPrice DECIMAL(18, 2),
		RecomendedRetailPrice DECIMAL(18, 2),
		TypicalWeightPerUnit DECIMAL(18, 2)
	);

	-- Select decrypted data.
	INSERT INTO @DecryptedStockItems
	SELECT 
		StockItemID,
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
		CONVERT(DECIMAL(18, 2), CONVERT(varbinary, decryptbykey([UnitPrice]))) as UnitPrice,
		RecomendedRetailPrice,
		TypicalWeightPerUnit
	FROM WWIGlobal.WWI.StockItem;
	
	CLOSE SYMMETRIC KEY WWIGlobalKey;


	-- Verifica se existe uma promoção para o item
	DECLARE @ExistPromotion BIT = CASE WHEN (
		SELECT COUNT(*) FROM WWI.PromotionGroup pg JOIN WWI.OrderList ol ON ol.StockItemID=pg.StockItemID JOIN WWI.StockItem si on si.StockItemID=pg.StockItemID JOIN WWI.Promotion pr on pr.PromotionID=pg.PromotionID WHERE si.StockItemID=@StockItemID
	) > 0 THEN 1 ELSE 0 END;

	IF @ExistPromotion = 1
	BEGIN
		-- Caso exista promoção.
		DECLARE @StartDate DATETIME, @EndDate DATETIME, @Discount decimal(18,3);
		SELECT @StartDate=pr.StartDate, @EndDate=pr.EndStart, @Discount=pr.Discount FROM WWI.PromotionGroup pg JOIN WWI.OrderList ol ON ol.StockItemID=pg.StockItemID JOIN WWI.StockItem si on si.StockItemID=pg.StockItemID JOIN WWI.Promotion pr on pr.PromotionID=pg.PromotionID WHERE si.StockItemID=@StockItemID;
		IF (GETDATE() BETWEEN @StartDate AND @EndDate)
		BEGIN
			DECLARE @DefaultUnitPrice DECIMAL(18,3);
			SELECT @DefaultUnitPrice=UnitPrice from @DecryptedStockItems WHERE StockItemID=@StockItemID;

			-- Aplica desconto.
			UPDATE WWI.OrderList 
			SET UnitPrice = (@DefaultUnitPrice - (@DefaultUnitPrice * (@Discount/100)))
			WHERE StockItemID = @StockItemID AND OrderID = @OrderID;
		END
	END
END
GO


