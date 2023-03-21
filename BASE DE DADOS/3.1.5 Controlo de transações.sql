USE WWIGlobal;
GO

--- Neste ficheiro ser�o apresentadas as solu��es com os campos encriptados.

--- Adicionar Produto a uma Venda.
CREATE OR ALTER PROCEDURE WWI.sp_AddProductToOrderWithIsolation(
	@OrderID int,
	@StockItemID int,
	@Quantity int
)
AS
BEGIN
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
	BEGIN TRANSACTION
		BEGIN TRY
			OPEN SYMMETRIC KEY WWIGlobalKey DECRYPTION
			BY CERTIFICATE WWIGlobalCert

			DECLARE @EncryptedPrice VARBINARY(MAX);
			SELECT @EncryptedPrice = CONVERT(DECIMAL(18, 2), CONVERT(varbinary, decryptbykey([UnitPrice]))) FROM WWIGlobal.WWI.StockItem WHERE StockItemID=@StockItemID;
			
			CLOSE SYMMETRIC KEY WWIGlobalKey;

			INSERT INTO WWIGlobal.WWI.OrderList(
				OrderID,
				StockItemID,
				Quantity,
				UnitPrice
			) VALUES(
				@OrderID,
				@StockItemID,
				@Quantity,
				@EncryptedPrice
			)

			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
			EXEC Logs.sp_ErrorHandling;
		END CATCH
END
GO

CREATE OR ALTER PROCEDURE WWI.sp_UpdatePriceOfItemStockWithIsolation(
	@StockItemID int,
	@Price DECIMAL(18, 2)
)
AS
BEGIN
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
	BEGIN TRANSACTION
		BEGIN TRY
			OPEN SYMMETRIC KEY WWIGlobalKey DECRYPTION
			BY CERTIFICATE WWIGlobalCert

			UPDATE WWIGlobal.WWI.StockItem SET UnitPrice=ENCRYPTBYKEY(KEY_GUID('WWIGlobalKey'), CONVERT(VARBINARY, @Price)) WHERE StockItemID=@StockItemID;

			CLOSE SYMMETRIC KEY WWIGlobalKey;
			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
			EXEC Logs.sp_ErrorHandling;
		END CATCH
END
GO

CREATE OR ALTER PROCEDURE WWI.sp_CalcTotalOfSoldWithIsolation(
	@OrderID int
)
AS
BEGIN
	ALTER DATABASE WWIGlobal SET ALLOW_SNAPSHOT_ISOLATION ON;
	SET TRANSACTION ISOLATION LEVEL SNAPSHOT
	BEGIN TRANSACTION
		BEGIN TRY
			OPEN SYMMETRIC KEY WWIGlobalKey DECRYPTION
			BY CERTIFICATE WWIGlobalCert

			SELECT WWI.fn_calculateOrderTotal(@OrderID)

			CLOSE SYMMETRIC KEY WWIGlobalKey;
			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION
			EXEC Logs.sp_ErrorHandling;
		END CATCH
END
GO


-- TESTES sp_CreateOrderWithIsolation

-- TESTES sp_UpdatePriceOfItemStockWithIsolation
-- Garantindo que o pre�o do produto nas vendas por finalizar n�o � alterado;
-- Esse caso � impossivel acontecer no modelo da base dados, porque o pre�o � armezenado na orderlist ao adicionar um produto devido as promo��es.
-- Mas tem um teste que n�o permite o pre�o de um produto ser motidificado enquando outra transaction estiver a usar.

-- Sess�o 1
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
BEGIN TRANSACTION
EXEC WWI.sp_UpdatePriceOfItemStockWithIsolation 1, 25
WAITFOR DELAY '00:00:04' -- aguarda 2 segundos antes de confirmar a transa��o
EXEC WWI.sp_UpdatePriceOfItemStockWithIsolation 1, 15
COMMIT TRANSACTION

-- Sess�o 2
BEGIN TRANSACTION
EXEC WWI.sp_UpdatePriceOfItemStockWithIsolation 1, 20
WAITFOR DELAY '00:00:02' -- aguarda 2 segundos antes de confirmar a transa��o
COMMIT TRANSACTION

-- Leitura dos dados.
OPEN SYMMETRIC KEY WWIGlobalKey DECRYPTION
BY CERTIFICATE WWIGlobalCert

SELECT CONVERT(DECIMAL(18, 2), CONVERT(varbinary, decryptbykey([UnitPrice]))) FROM WWIGlobal.WWI.StockItem WHERE StockItemID=1

CLOSE SYMMETRIC KEY WWIGlobalKey;

-- Testes sp_CalcTotalOfSoldWithIsolation
-- Calcular o total da venda e/ou a quantidade de produtos na venda sem permitir adi��o ouremo��o de produtos na venda

-- Sess�o 1

WAITFOR DELAY '00:00:02'
EXEC WWI.sp_CalcTotalOfSoldWithIsolation 1
WAITFOR DELAY '00:00:04'
EXEC WWI.sp_CalcTotalOfSoldWithIsolation 1

-- Sess�o 2

BEGIN TRANSACTION
EXEC WWI.sp_AddProductToOrderWithIsolation 1, 204, 20
WAITFOR DELAY '00:00:02'
EXEC WWI.sp_AddProductToOrderWithIsolation 1, 201, 20
WAITFOR DELAY '00:00:03'
EXEC WWI.sp_AddProductToOrderWithIsolation 1, 202, 20
COMMIT TRANSACTION

