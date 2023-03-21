USE WWIGlobal;
GO

-- O processo em que Cria as chaves de Encripta��o j� foi feito no arquivo "3.1.4 Encripta��o".
-- Ent�o vamos verificar se as chaves j� existem e se n�o criar.

-- Verifica se a chave sim�trica
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = 'WWIGlobalKey')
CREATE MASTER KEY ENCRYPTION
BY PASSWORD = 'WWIGlobal2023'
GO


-- Verifica se o certificado
IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = 'WWIGlobalCert')
CREATE CERTIFICATE WWIGlobalCert
WITH SUBJECT = 'Protect Data'
GO

-- GO se a Master Key 
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name LIKE '%DatabaseMasterKey%')
CREATE SYMMETRIC KEY WWIGlobalKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE WWIGlobalCert;
GO

-- Abrir a chave simetrica.
OPEN SYMMETRIC KEY WWIGlobalKey DECRYPTION
BY CERTIFICATE WWIGlobalCert
GO


SELECT * FROM WWI.Transport;

-- Para realizar a encripta��o do campo "TrackingNumber" � preciso alter o tipo do campo da tabela para varbinary.
-- Como o valor � nvarchar o sql server n�o permite a sua convers�o automatica ent�o � preciso criar um campo temporario.

ALTER TABLE WWI.Transport
ADD TrackingNumberTemp varbinary(4000)
GO

-- Copiar os dados e convertidos
UPDATE WWI.Transport SET TrackingNumberTemp=CONVERT(varbinary(4000), TrackingNumber);

-- Drop do campo Tracking Number
ALTER TABLE WWI.Transport
DROP COLUMN TrackingNumber;

-- Adicionar Campo novamente com formato certo
ALTER TABLE WWI.Transport
ADD TrackingNumber varbinary(4000)
GO

-- Copiar os Valores e encriptalos
UPDATE WWI.Transport SET TrackingNumber=ENCRYPTBYKEY(KEY_GUID('WWIGlobalKey'), TrackingNumberTemp)

-- Drop da coluna temporaria
ALTER TABLE WWI.Transport
DROP COLUMN TrackingNumberTemp;

SELECT * FROM WWI.Transport;

-- Fechar Chave simetrica
CLOSE SYMMETRIC KEY WWIGlobalKey;
GO


--- ler dados encriptados.

-- Abrir a chave simetrica.
OPEN SYMMETRIC KEY WWIGlobalKey DECRYPTION
BY CERTIFICATE WWIGlobalCert
GO

SELECT *, CONVERT(NVARCHAR(4000), CONVERT(varbinary(4000), decryptbykey(TrackingNumber))) AS DecryptedTrackingNumber FROM WWIGlobal.WWI.Transport
GO

-- Fechar Chave simetrica
CLOSE SYMMETRIC KEY WWIGlobalKey;
GO