USE WWIGlobal;
GO

-- Drop os índices se já existirem
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IDX_Transport')
	DROP INDEX IDX_Transport ON WWI.Transport;
GO

-- Criação da view.
CREATE OR ALTER VIEW WWI.VW_TransportDeliveryTime
AS SELECT 
    lo.LogisticName,
    ROUND(CAST(AVG(DATEDIFF(HOUR, tr.ShippingDate, tr.DeliveryDate))AS float) / 24, 2) AS AvgDeliveryTime
FROM 
    WWI.Transport tr
    JOIN WWI.Logistic lo ON tr.LogisticID = lo.LogisticID
WHERE 
    tr.DeliveryDate IS NOT NULL
GROUP BY 
    lo.LogisticName;
GO

-- Teste.
SELECT * FROM WWI.VW_TransportDeliveryTime;
GO


-- Adicionar os Indixes.
-- Como o tunning advisor não recomendou nenhum indexes vou aplicar indixes ao campos do where na tentiva de melhorar o desempenho.

CREATE NONCLUSTERED INDEX IDX_Transport
ON WWI.Transport(LogisticID, ShippingDate, DeliveryDate);


SET STATISTICS IO ON
GO

-- Teste.
SELECT * FROM WWI.VW_TransportDeliveryTime;
GO

SET STATISTICS IO OFF
GO