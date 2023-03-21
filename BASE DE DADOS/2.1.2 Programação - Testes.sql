USE WWIGlobal;
GO

-- Teste da funcionalidade de encriptação de passwords.
BEGIN
	SELECT WWI.fnEncryptPassword('Password Used For Teste') as EncryptedPassword;
END
GO

-- Teste da recuperação de utilizador e a autenticação.
BEGIN
	-- Apaga todas as tentativas anteriores.
	DELETE FROM WWI.Recovery WHERE CustomerID=(SELECT CustomerID FROM WWI.Customer WHERE CustomerEmail='teste@gmail.com');
	
	-- Apaga o 'customer' de teste.
	DELETE FROM WWI.Customer WHERE CustomerEmail='teste@gmail.com';

	-- Cria um novo 'customer'.
	INSERT INTO WWI.Customer(
		BillToCustomerID,
		BuyingGroupID,
		CustomerCategoryID,
		CustomerName,
		CustomerPrimaryContact,
		CustomerEmail,
		CustomerPassword,
		CustomerZipCode,
		CustomerIsHeadOffice
	) VALUES(
		1,
		1,
		1,
		'Utilizador de Teste',
		'Teste',
		'teste@gmail.com',
		WWI.fnEncryptPassword('teste'),
		'287612',
		1
	);


	-- Verificar se o 'customer' existe
	SELECT * FROM WWI.Customer WHERE CustomerEmail='teste@gmail.com';

	-- Tenta autenticar
	EXEC WWI.sp_AuthenticateCustomer 'teste@gmail.com', 'test' -- Wrong Password

	EXEC WWI.sp_AuthenticateCustomer 'teste@gmail.com', 'teste' -- Correct Password

	-- Recuperação de Password
	EXEC WWI.sp_GenerateRecoveryToken 'teste@gmail.com'

	-- Troca a password para teste1234
	DECLARE @SQLRUN NVARCHAR(MAX);
	SET @SQLRUN = 'EXEC WWI.sp_ResetPasswordWithToken '
	SELECT @SQLRUN = @SQLRUN +''''+ CONVERT(nvarchar(256), re.RecoveryToken) + ''', ''teste1234''' FROM WWI.Recovery re INNER JOIN WWI.Customer cu on re.CustomerID=cu.CustomerID WHERE cu.CustomerEmail='teste@gmail.com' AND re.RecoveryCreateAt=(
		SELECT MAX(re.RecoveryCreateAt)FROM WWI.Recovery re INNER JOIN WWI.Customer cu on re.CustomerID=cu.CustomerID WHERE cu.CustomerEmail='teste@gmail.com'
	);
	print @SQLRUN
	EXEC(@SQLRUN)

	EXEC WWI.sp_AuthenticateCustomer 'teste@gmail.com', 'teste' -- Wrong Password

	EXEC WWI.sp_AuthenticateCustomer 'teste@gmail.com', 'teste1234' -- Correct Password

END
GO

-- Promoções
BEGIN
	SELECT * FROM WWI.OrderList WHERE OrderID=1;

	SELECT WWI.fn_calculateOrderTotal(1) AS 'Total Order';

	EXEC WWI.sp_AddPromotion 5, 'Carnaval', '2023-02-13','2023-02-27'

	EXEC WWI.sp_InsertProductIntoPromotion 1, 1


	SELECT * FROM WWI.Customer WHERE CustomerEmail='teste@gmail.com';

	EXEC WWI.sp_CreateOrder 403, 1, 1, 287612

	SELECT * FROM WWI.Orders where OrderDate=(SELECT MAX(OrderDate) FROM WWI.Orders)
	DELETE FROM WWI.OrderList WHERE OrderID=128484

	EXEC WWI.sp_InsertOrderItem 128484, 1, 5

	SELECT * FROM WWI.OrderList WHERE OrderID=128484;

	SELECT * FROM WWI.OrderList WHERE OrderID=128484;

	SELECT WWI.fn_calculateOrderTotal(128484) AS 'Total Order';


	-- Nao permitir chiller stock
	EXEC WWI.sp_InsertOrderItem 128484, 14, 5
END
GO