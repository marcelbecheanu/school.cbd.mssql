USE WWIGlobal;
GO

-- Testar Geradores

EXEC WWI.sp_generator_insert 'Customer'
GO


EXEC WWI.Customer_insert 1,1,1,'Teste PrimaryContact','Nome', 'email','password','20913', 0, '2023-02-21'
GO

SELECT * FROM WWI.Customer WHERE CustomerEmail='email';


EXEC WWI.sp_generator_update 'Customer'
GO

EXEC WWI.Customer_update 404,1,1,1,'22222 PrimaryContact','Nome', 'email','password','20913', 0, '2023-02-21'
GO

SELECT * FROM WWI.Customer WHERE CustomerEmail='email';

EXEC WWI.sp_generator_delete 'Customer'
GO

EXEC WWI.Customer_delete 404
GO

SELECT * FROM WWI.Customer WHERE CustomerEmail='email';

exec WWI.sp_monitoring
GO

SELECT * FROM WWI.LastMonitoring;

exec WWI.sp_monitoringstorage
GO

SELECT * FROM WWI.LastMonitoringStorage