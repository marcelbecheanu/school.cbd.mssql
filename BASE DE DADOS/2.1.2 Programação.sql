USE WWIGlobal;
GO

-- Função que recebe uma senha e retorna um hash dela.
CREATE OR ALTER FUNCTION WWI.fnEncryptPassword(@password varchar(128))
RETURNS varchar(255)
BEGIN
	RETURN CONVERT(NVARCHAR(255), HASHBYTES('SHA2_512', @Password), 2);
END
GO

-- Procedure que regista informações sobre erros em uma tabela de log.
CREATE OR ALTER PROCEDURE Logs.sp_ErrorHandling
AS
BEGIN
	-- Declaração de variáveis para armazenar informações sobre o erro.
	DECLARE @ErrorUserName VARCHAR(128) = SUSER_SNAME();
	DECLARE @ErrorNumber INT = ERROR_NUMBER();
	DECLARE @ErrorState INT = ERROR_STATE();
	DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
	DECLARE @ErrorLine INT = ERROR_LINE();
	DECLARE @ErrorProcedure VARCHAR(128) = ERROR_PROCEDURE();
	DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
	DECLARE @ErrorDate DATETIME = GETDATE();

	-- Mostra de forma amigável o erro.
	SELECT @ErrorUserName AS ErrorUserName, @ErrorNumber AS ErrorNumber, @ErrorSeverity AS ErrorSeverity, @ErrorLine AS ErrorLine, @ErrorState AS ErrorState, @ErrorProcedure AS ErrorProcedure, @ErrorMessage AS ErrorMessage, @ErrorDate AS ErrorDate;
	PRINT 'An error occurred during execution: ' + @ErrorMessage;

	-- Insere as informações do erro na tabela de log.
	INSERT INTO Logs.Error
	VALUES (@ErrorUserName, @ErrorNumber, @ErrorState, @ErrorSeverity, @ErrorLine, @ErrorProcedure, @ErrorMessage, @ErrorDate);
END
GO

-- Gestão dos 'Customers'.
-- Procedure de responsável pelá autenticação dos 'Customers'.
CREATE OR ALTER PROCEDURE WWI.sp_AuthenticateCustomer
(
	@Email NVARCHAR(256),
	@Password NVARCHAR(256)
) AS BEGIN
	BEGIN TRY
		DECLARE @Id INT;
		SELECT @Id=CustomerID
			FROM WWI.Customer cs
			WHERE upper(cs.CustomerEmail)=upper(@Email) AND cs.CustomerPassword = WWI.fnEncryptPassword(@Password)

		IF @Id IS NOT NULL
		BEGIN
			Declare @CustomerName NVARCHAR(255);
			SET @CustomerName = (SELECT CustomerName FROM WWI.Customer cs WHERE CustomerID=@Id);
			PRINT 'Login successful, welcome ' + CONVERT(NVARCHAR(255), @Id) + ' ' + @CustomerName
		END
		ELSE
		BEGIN
			PRINT 'Invalid email or password.'
		END
	END TRY
	BEGIN CATCH
		PRINT 'An error occurred while authenticating the user.'
		EXEC Logs.sp_ErrorHandling
	END CATCH
END
GO

-- Gera um token de recuperação para o 'customer' com o email informado.
CREATE OR ALTER PROCEDURE WWI.sp_GenerateRecoveryToken
(
	@Email NVARCHAR(256)
) AS BEGIN
	BEGIN TRY
		DECLARE @UserId INT;
		SELECT @UserId = CustomerID FROM WWI.Customer WHERE UPPER(CustomerEmail) = UPPER(@Email);
		DECLARE @token VARCHAR(255) = CONVERT(VARCHAR(255), NEWID());
		SET @token = REPLACE(@token, '-', '');

		IF @UserId IS NOT NULL
		BEGIN
			INSERT INTO WWI.Recovery (CustomerID, RecoveryToken) VALUES (@UserId, @token);
			PRINT 'A new recovery token has been generated for user with email ' + @Email + ': ' + @token;
		END
		ELSE
		BEGIN
			PRINT 'Failed to generate recovery token. User with email ' + @Email + ' not found.';
		END
	END TRY
	BEGIN CATCH
		PRINT 'An error occurred while generating recovery token.';
		EXEC Logs.sp_ErrorHandling;
	END CATCH
END
GO

-- Utiliza um token de recuperação para o 'customer' e recupera sua password.
CREATE OR ALTER PROCEDURE WWI.sp_ResetPasswordWithToken
(
	@Token NVARCHAR(256),
	@NewPassword NVARCHAR(256)
) AS
BEGIN
	BEGIN TRY
	
		DECLARE @CustomerID INT;
		DECLARE @RecoverID INT;
		DECLARE @CreatedAt DATETIME;

		SELECT @RecoverID = re.RecoveryID, @CustomerID= re.CustomerID, @CreatedAt=re.RecoveryCreateAt
		FROM WWI.Recovery re
		WHERE re.RecoveryToken=@Token;
		
		IF @RecoverID IS NOT NULL
		BEGIN
			IF(GETDATE() > DATEADD(HOUR, +24, @CreatedAt))
			BEGIN
				PRINT 'The token has expired. Invalid Token.';
				DELETE FROM WWI.Recovery WHERE RecoveryToken=@Token
			END
			ELSE
			BEGIN
				UPDATE WWI.Customer SET CustomerPassword=WWI.fnEncryptPassword(@NewPassword) WHERE CustomerID=@CustomerID;
				PRINT 'Password has been updated successfully.'
			END
		END
		ELSE
		BEGIN
			PRINT 'Invalid Token.';
		END

	END TRY
	BEGIN CATCH
		PRINT 'An error occurred while recover the password of user.'
		EXEC Logs.sp_ErrorHandling
	END CATCH
END
GO


-- Criar Promoção --
CREATE OR ALTER PROCEDURE WWI.sp_AddPromotion(
	@Discount DECIMAL(18, 3),
	@Description NVARCHAR(256),
	@StartDate DATETIME,
	@EndDate DATETIME
) AS
BEGIN
	BEGIN TRY
		IF @StartDate > @EndDate or @EndDate < GETDATE() or @StartDate < GETDATE()
		BEGIN
			PRINT 'The end date of the promotion must be later than the start date and must still be valid.'
		END
		ELSE
		BEGIN
			INSERT INTO WWI.Promotion(Description, Discount, EndStart, StartDate) VALUES(@Description, @Discount, @EndDate, @StartDate);
			PRINT 'Promotion has created.'
		END
	END TRY
	BEGIN CATCH
		EXEC Logs.sp_ErrorHandling
	END CATCH
END
GO

-- Alterar datas -- 
CREATE OR ALTER PROCEDURE WWI.sp_UpdatePromotionDates
(
    @PromotionID INT,
    @StartDate DATETIME,
    @EndDate DATETIME
) AS
BEGIN
    BEGIN TRY
        IF @StartDate > @EndDate or @EndDate < GETDATE() or @StartDate < GETDATE()
        BEGIN
            PRINT 'The end date of the promotion must be later than the start date and must still be valid.'
        END
        ELSE
        BEGIN
            IF EXISTS (SELECT PromotionID FROM WWI.Promotion WHERE PromotionID = @PromotionID)
            BEGIN
                UPDATE WWI.Promotion SET StartDate=@StartDate, EndStart=@EndDate WHERE PromotionID=@PromotionID;
                PRINT 'Updated promotion dates.'
            END
            ELSE
            BEGIN
                PRINT 'Can´t find this promotion.'
            END
        END
    END TRY
    BEGIN CATCH
        EXEC Logs.sp_ErrorHandling
    END CATCH
END
GO

-- Adicionar um produto a promoção.
CREATE OR ALTER PROCEDURE WWI.sp_InsertProductIntoPromotion
(
	@PromotionID INT,
	@StockItemID INT
) AS
BEGIN
	BEGIN TRY
		IF EXISTS(SELECT PromotionID FROM WWI.Promotion WHERE PromotionID=@PromotionID)
		BEGIN
			IF EXISTS(SELECT StockItemID FROM WWI.StockItem WHERE StockItemID=@StockItemID)
			BEGIN
				IF NOT EXISTS(SELECT StockItemID FROM WWI.PromotionGroup WHERE StockItemID=@StockItemID)
				BEGIN
					INSERT INTO PromotionGroup(PromotionID, StockItemID) VALUES(@PromotionID, @StockItemID);
					PRINT 'Product has added to promotion.'
				END
				ELSE
				BEGIN 
					PRINT 'This product already exists in promotion.'
				END
			END
			ELSE
			BEGIN
				PRINT 'This product id is invalid.'
			END
		END
		ELSE
		BEGIN
			PRINT 'This promotion id is invalid.'
		END
	END TRY
	BEGIN CATCH
		EXEC Logs.sp_ErrorHandling
	END CATCH
END
GO

--- ORDERS ---

-- Este procedimento armazenado é usado para criar uma encomenda/pedido/venda.
CREATE OR ALTER PROCEDURE WWI.sp_CreateOrder(
	@CustomerID INT,
	@EmployeeID INT,
	@CityID INT,
	@InvoiceID INT
) AS
BEGIN
	BEGIN TRY
		INSERT INTO WWI.Orders(CustomerID, EmployeeID, CityID, InvoiceID) VALUES(@CustomerID, @EmployeeID, @CityID, @InvoiceID);
	END TRY
	BEGIN CATCH
		EXEC Logs.sp_ErrorHandling
	END CATCH
END
GO

-- Este procedimento armazenado é usado para adicionar um item em um pedido.
CREATE OR ALTER PROCEDURE WWI.sp_InsertOrderItem(
	@OrderID INT,
	@StockItemID INT,
	@Quantity INT
) AS
BEGIN
	BEGIN TRY
		DECLARE @UnitPrice DECIMAL(18,3);
		SELECT @UnitPrice = si.UnitPrice from WWI.StockItem si WHERE StockItemID=@StockItemID
		INSERT INTO OrderList(OrderID, StockItemID, Quantity, UnitPrice) VALUES(@OrderID, @StockItemID, @Quantity, @UnitPrice);
		PRINT 'Product has added to sale.'
	END TRY
	BEGIN CATCH
		EXEC Logs.sp_ErrorHandling
	END CATCH
END
GO

-- Este procedimento armazenado é usado para atualizar a quantidade um item em um pedido.
CREATE OR ALTER PROCEDURE WWI.sp_UpdateOrderProductQuantity(
	@OrderID INT,
	@StockItemID INT,
	@Quantity INT
) AS
BEGIN
	BEGIN TRY
		UPDATE WWI.OrderList SET Quantity=@Quantity WHERE OrderID=@OrderID AND StockItemID=@StockItemID;
		PRINT 'Quantity of produto has changed.'
	END TRY
	BEGIN CATCH
		EXEC Logs.sp_ErrorHandling
	END CATCH
END
GO


-- Este procedimento armazenado é usado para remover um item de um pedido
-- ou o próprio pedido inteiro, dependendo do valor do
-- parâmetro de entrada @RemoveWholeOrder.
CREATE OR ALTER PROCEDURE WWI.sp_RemoveOrderItem(
	@OrderID INT,
	@StockItemID INT,
	@RemoveWholeOrder  BIT
)AS
BEGIN
	BEGIN TRY
		-- Se @RemoveWholeOrder = 0, remove o item especificado do pedido
		IF @RemoveWholeOrder = 0
		BEGIN
			DELETE FROM WWI.OrderList WHERE OrderID=@OrderID AND StockItemID=@StockItemID;
			PRINT 'Product has removed from Order.'
		END
		-- Se @RemoveWholeOrder  = 1, remove o pedido inteiro
		ELSE
		BEGIN
			DELETE FROM WWI.OrderList WHERE OrderID=@OrderID;
			DELETE FROM WWI.Orders WHERE OrderID=@OrderID;
			PRINT 'Order has removed.'
		END
	END TRY
	BEGIN CATCH
		EXEC Logs.sp_ErrorHandling
	END CATCH
END
GO


-- Calcula o preço total de uma venda.
CREATE or ALTER FUNCTION WWI.fn_calculateOrderTotal
(
	@OrderID INT
) returns DECIMAL(18,3) AS
BEGIN
	-- Declaração de uma variável para armazenar o preço total calculado.
	DECLARE @TotalPrice DECIMAL(18, 3) = 0.000;

	-- Utilização de uma instrução SELECT para calcular a soma do preço total de todos os itens na encomenda, tendo em conta a taxa.
	SELECT @TotalPrice = SUM((ol.Quantity * ol.UnitPrice) * (1 + tr.TaxRate / 100))
	FROM WWI.OrderList ol
	JOIN WWI.StockItem si ON si.StockItemID = ol.StockItemID
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
		
		-- Obter o ID da encomenda atual e o tempo de espera, que é retornado pela função fn_CheckOrderLeadTime.
		-- A função retorna 0 se a encomenda não estiver atrasada, caso contrário, retorna o número de dias de atraso.
		SELECT @currentOrderID = OrderID, @leadTime = WWI.fn_CheckOrderLeadTime(OrderID)
		FROM INSERTED;
		

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
			SELECT @DefaultUnitPrice=UnitPrice from WWI.StockItem WHERE StockItemID=@StockItemID;

			-- Aplica desconto.
			UPDATE WWI.OrderList 
			SET UnitPrice = (@DefaultUnitPrice - (@DefaultUnitPrice * (@Discount/100)))
			WHERE StockItemID = @StockItemID AND OrderID = @OrderID;
		END
	END
END
GO