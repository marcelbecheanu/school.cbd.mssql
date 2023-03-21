USE MASTER;

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'LogisticUser')
BEGIN
    DROP LOGIN LogisticUser;
END

-- Cria o login".
CREATE LOGIN LogisticUser WITH PASSWORD = 'LogisticUser123456';
GO

USE WWIGlobal;

IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'LogisticUser')
BEGIN
    DROP USER LogisticUser;
END
GO

-- Cria o utilizador "LogisticUser"
CREATE USER LogisticUser FOR LOGIN LogisticUser;

-- Concede acesso total à view do tópico 2.2.1
GRANT ALL ON WWI.VW_TransportDeliveryTime TO LogisticUser;

-- Concede acesso às tabelas de gestão de transportes
GRANT ALL ON WWI.Transport TO LogisticUser;
GRANT ALL ON WWI.Logistic TO LogisticUser;

-- Concede apenas permissão de consulta às tabelas associadas às vendas
GRANT SELECT ON WWI.Orders TO LogisticUser;
GRANT SELECT ON WWI.OrderList TO LogisticUser;
GRANT SELECT ON WWI.StockItem TO LogisticUser;


------- TESTES ----------
EXECUTE AS USER = 'LogisticUser';

-- Não permitir realizar o Select
SELECT * FROM WWI.Color;

-- Não permitir realizar o Insert
INSERT INTO WWI.Color(ColorName) 
VALUES('tsawdawdawd')


--  Concede acesso total à view do tópico 2.2.1
SELECT * FROM WWI.VW_TransportDeliveryTime;

-- Realizar insert  às tabelas de gestão de transportes
INSERT INTO WWI.Logistic(LogisticName) VALUES('TESTE');
INSERT INTO WWI.Transport(SaleID,LogisticID, DeliveryDate, ShippingDate, TrackingNumber)
VALUES(
	2378174,
	(SELECT TOP 1 LogisticID FROM WWI.Logistic WHERE LogisticName='TESTE'),
	GETDATE()+3,
	GETDATE(),
	NEWID()
)

SELECT * FROM WWI.Logistic WHERE LogisticName='TESTE';
SELECT * FROM WWI.Transport WHERE LogisticID=(SELECT TOP 1 LogisticID FROM WWI.Logistic WHERE LogisticName='TESTE');

SELECT * FROM WWI.VW_TransportDeliveryTime;

SELECT * FROM WWI.Orders;
SELECT * FROM WWI.OrderList;
SELECT * FROM WWI.StockItem;

REVERT -- Voltar ao user anterior
GO