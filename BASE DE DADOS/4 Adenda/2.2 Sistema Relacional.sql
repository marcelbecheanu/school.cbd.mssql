USE WWIGlobal;

-- Verifica se as tabelas já existem.
IF OBJECT_ID('WWI.Transport', 'U') IS NOT NULL
	DROP TABLE WWI.Transport;

IF OBJECT_ID('WWI.Logistic', 'U') IS NOT NULL
	DROP TABLE WWI.Logistic;

-- Criação das tabelas.
IF OBJECT_ID('WWI.Logistic', 'U') IS NULL
	CREATE TABLE WWI.Logistic (
		LogisticID INT NOT NULL IDENTITY(1, 1),
		LogisticName NVARCHAR(60) NOT NULL,
		CONSTRAINT PK_Logistic
			PRIMARY KEY (LogisticID),
		CONSTRAINT UQ_LogisticName
			UNIQUE (LogisticName),
	);

IF OBJECT_ID('WWI.Transport', 'U') IS NULL
	CREATE TABLE WWI.Transport (
		TransportID INT NOT NULL IDENTITY(1, 1),
		LogisticID INT NOT NULL,
		SaleID INT NOT NULL,
		ShippingDate DATETIME NOT NULL,
		DeliveryDate DATETIME NULL,
		TrackingNumber NVARCHAR(120) NOT NULL,
		CONSTRAINT PK_Transport
			PRIMARY KEY (TransportID),
		CONSTRAINT FK_LogisticTransport
			FOREIGN KEY (LogisticID)
			REFERENCES WWI.Logistic(LogisticID),
	);

-- Importar dados do json.
-- INSERT INTO Logistic.
BEGIN
	Declare @JSON varchar(max);
	SELECT @JSON=BulkColumn FROM OPENROWSET (BULK 'C:\Users\Marce\Desktop\NEW DATABASE\Adenda\Logistic.json', SINGLE_CLOB) import;

	INSERT INTO WWI.Logistic(LogisticName)
	SELECT * FROM OPENJSON(@JSON)
	WITH (
		LogisticName NVARCHAR(100) '$.name'
	)
END
GO

-- INSERT INTO TRANSPORT
BEGIN
	Declare @JSON varchar(max);
	SELECT @JSON=BulkColumn FROM OPENROWSET (BULK 'C:\Users\Marce\Desktop\NEW DATABASE\Adenda\Transport.json', SINGLE_CLOB) import;

	INSERT INTO WWI.Transport(LogisticID, SaleID, ShippingDate, DeliveryDate, TrackingNumber)
	SELECT
		(SELECT TOP 1 LogisticID FROM WWI.Logistic WHERE LogisticName = LName) AS LogisticID,
		SaleID,
		ShippingDate,
		DeliveryDate,
		TrackingNumber
	FROM OPENJSON(@JSON)
	WITH (
		SaleID int '$.saleid',
		LName NVARCHAR(60) '$.name',
		ShippingDate nvarchar(50) '$.shippingDate',
		DeliveryDate nvarchar(50) '$.deliveryDate',
		TrackingNumber nvarchar(120) '$.trackingNumber'
	)
END

SELECT * FROM WWI.Logistic;
SELECT * FROM WWI.Transport;
-- 