USE WWIGlobal;
GO

-- Gerador de Procedimentos - Recebem como paremtro o nome da tabela.
-- insert
CREATE OR ALTER PROCEDURE WWI.sp_generator_insert(
	@tableName varchar(255)
) AS
BEGIN
	BEGIN TRY
		DECLARE @sql VARCHAR(MAX);
		DECLARE @params VARCHAR(MAX);
		DECLARE @data VARCHAR(MAX);
		DECLARE @dataFromProcedure VARCHAR(MAX);


		-- Obtém todos os dados necessários da tabela para construir a consulta. 
		DECLARE Cols CURSOR FOR
			SELECT
				COLUMN_NAME as colName,
				DATA_TYPE as dataType,
				CHARACTER_MAXIMUM_LENGTH as size,
				CASE
					WHEN EXISTS (
						SELECT *
						FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
						JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu 
						ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
						WHERE kcu.TABLE_NAME = @tableName AND kcu.TABLE_SCHEMA = 'WWI' 
						AND kcu.COLUMN_NAME = COLUMNS.COLUMN_NAME
						AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
					) THEN 1
					ELSE 0
				END AS isPrimaryKey,
				CASE
					WHEN EXISTS (
						SELECT *
						FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
						JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu 
						ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
						WHERE kcu.TABLE_NAME = @tableName AND kcu.TABLE_SCHEMA = 'WWI' 
						AND kcu.COLUMN_NAME = COLUMNS.COLUMN_NAME
						AND tc.CONSTRAINT_TYPE = 'FOREIGN KEY'
					) THEN 1
					ELSE 0
				END AS isForeignKey
			FROM INFORMATION_SCHEMA.COLUMNS
			WHERE
				TABLE_NAME = @tableName AND TABLE_SCHEMA = 'WWI';


	
		-- Variaveis usadas para construir o procedure.
		DECLARE @colName VARCHAR(MAX);
		DECLARE @dataType VARCHAR(MAX);
		DECLARE @size VARCHAR(MAX);
		DECLARE @isPrimaryKey bit;
		DECLARE @isForeignKey bit;


		SET @params = '';
		SET @data = '';
		SET @dataFromProcedure = '';

		-- Percorre linha por linha para construir os parametros necessarios.
		OPEN Cols
			FETCH NEXT FROM Cols INTO @colName, @dataType, @size, @isPrimaryKey, @isForeignKey
			WHILE @@FETCH_STATUS = 0
			BEGIN
			
				-- Adiciona se não for uma chave primaria ou se for uma ForeignKey.
				IF(@isPrimaryKey = 0 or @isForeignKey = 1) 
				BEGIN
					SET @params = CASE WHEN @size IS NULL THEN @params + '@' + @colName + ' ' + @dataType + ',' ELSE @params + '@' + @colName + ' ' + @dataType + '('+@size+')'+',' END;
					SET @data = @data + @colName + ', '
					SET @dataFromProcedure = @dataFromProcedure + '@'+ @colName+',';
				END
		
				FETCH NEXT FROM Cols INTO @colName, @dataType, @size, @isPrimaryKey, @isForeignKey
			END
		CLOSE Cols
		DEALLOCATE Cols

		SET @params = LEFT(@params, LEN(@params) - 1);
		SET @data = LEFT(@data, LEN(@data) - 1);
		SET @dataFromProcedure = LEFT(@dataFromProcedure, LEN(@dataFromProcedure) - 1);


		-- Adiciona o texto para a contrução do procedure.
		SET @sql = '
			CREATE OR ALTER PROCEDURE WWI.'+@tableName+'_insert
			(
				' + @params + '
			)
			AS
			BEGIN TRY
				INSERT INTO WWI.' + @tableName + '(' + @data +') VALUES ('
					+ @dataFromProcedure +
				')
			END TRY
			BEGIN CATCH
				EXEC Logs.sp_ErrorHandling
			END CATCH
		'

		EXEC(@sql)

	END TRY
	BEGIN CATCH
		EXEC Logs.sp_ErrorHandling
	END CATCH
END
GO

-- update
CREATE OR ALTER PROCEDURE WWI.sp_generator_update(
	@tableName varchar(255)
) AS
BEGIN
	BEGIN TRY
	
		DECLARE @sql VARCHAR(MAX);
		DECLARE @params VARCHAR(MAX);
		DECLARE @data VARCHAR(MAX);
		DECLARE @where VARCHAR(MAX);


		-- Obtém todos os dados necessários da tabela para construir a consulta. 
		DECLARE Cols CURSOR FOR
			SELECT
				COLUMN_NAME as colName,
				DATA_TYPE as dataType,
				CHARACTER_MAXIMUM_LENGTH as size,
				CASE
					WHEN EXISTS (
						SELECT *
						FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
						JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu 
						ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
						WHERE kcu.TABLE_NAME = @tableName AND kcu.TABLE_SCHEMA = 'WWI' 
						AND kcu.COLUMN_NAME = COLUMNS.COLUMN_NAME
						AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
					) THEN 1
					ELSE 0
				END AS isPrimaryKey,
				CASE
					WHEN EXISTS (
						SELECT *
						FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
						JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu 
						ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
						WHERE kcu.TABLE_NAME = @tableName AND kcu.TABLE_SCHEMA = 'WWI' 
						AND kcu.COLUMN_NAME = COLUMNS.COLUMN_NAME
						AND tc.CONSTRAINT_TYPE = 'FOREIGN KEY'
					) THEN 1
					ELSE 0
				END AS isForeignKey
			FROM INFORMATION_SCHEMA.COLUMNS
			WHERE
				TABLE_NAME = @tableName AND TABLE_SCHEMA = 'WWI';


	
		-- Variaveis usadas para construir o procedure.
		DECLARE @colName VARCHAR(MAX);
		DECLARE @dataType VARCHAR(MAX);
		DECLARE @size VARCHAR(MAX);
		DECLARE @isPrimaryKey bit;
		DECLARE @isForeignKey bit;


		SET @params = '';
		SET @data = '';
		SET @where = '';

		-- Percorre linha por linha para construir os parametros necessarios.
		OPEN Cols
			FETCH NEXT FROM Cols INTO @colName, @dataType, @size, @isPrimaryKey, @isForeignKey
			WHILE @@FETCH_STATUS = 0
			BEGIN
			
				-- Adiciona se não for uma chave primaria ou se for uma ForeignKey.
				IF(@isPrimaryKey = 0 or @isForeignKey = 1) 
				BEGIN
					SET @data = @data + @colName + '=@'+@colName+','
				END

				-- Paremetros de entreda são todos os campos
				SET @params = CASE WHEN @size IS NULL THEN @params + '@' + @colName + ' ' + @dataType + ',' ELSE @params + '@' + @colName + ' ' + @dataType + '('+@size+')'+',' END;
			
				-- Update pelos primary key.
				IF(@isPrimaryKey = 1)
				BEGIN
					SET @where = @where + @colName + '=@' +@colName + ' AND ';
				END
		
				FETCH NEXT FROM Cols INTO @colName, @dataType, @size, @isPrimaryKey, @isForeignKey
			END
		CLOSE Cols
		DEALLOCATE Cols

		SET @params = LEFT(@params, LEN(@params) - 1);
		SET @data = LEFT(@data, LEN(@data) - 1);
		SET @where = LEFT(@where, LEN(@where) - 4);



		-- Adiciona o texto para a contrução do procedure.
		SET @sql = '
			CREATE OR ALTER PROCEDURE WWI.'+@tableName+'_update
			(
				' + @params + '
			)
			AS
			BEGIN TRY
				UPDATE WWI.' + @tableName + ' SET '
				+ @data +
				' WHERE ' + @where + ';
			END TRY
			BEGIN CATCH
				EXEC Logs.sp_ErrorHandling
			END CATCH
		'
		EXEC(@sql)

	END TRY
	BEGIN CATCH
		EXEC Logs.sp_ErrorHandling
	END CATCH
END
GO


-- delete
CREATE OR ALTER PROCEDURE WWI.sp_generator_delete(
	@tableName varchar(255)
) AS
BEGIN
	BEGIN TRY
	
		DECLARE @sql VARCHAR(MAX);
		DECLARE @params VARCHAR(MAX);
		DECLARE @where VARCHAR(MAX);


		-- Obtém todos os dados necessários da tabela para construir a consulta. 
		DECLARE Cols CURSOR FOR
			SELECT
				COLUMN_NAME as colName,
				DATA_TYPE as dataType,
				CHARACTER_MAXIMUM_LENGTH as size,
				CASE
					WHEN EXISTS (
						SELECT *
						FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
						JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu 
						ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
						WHERE kcu.TABLE_NAME = @tableName AND kcu.TABLE_SCHEMA = 'WWI' 
						AND kcu.COLUMN_NAME = COLUMNS.COLUMN_NAME
						AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
					) THEN 1
					ELSE 0
				END AS isPrimaryKey,
				CASE
					WHEN EXISTS (
						SELECT *
						FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
						JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu 
						ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
						WHERE kcu.TABLE_NAME = @tableName AND kcu.TABLE_SCHEMA = 'WWI' 
						AND kcu.COLUMN_NAME = COLUMNS.COLUMN_NAME
						AND tc.CONSTRAINT_TYPE = 'FOREIGN KEY'
					) THEN 1
					ELSE 0
				END AS isForeignKey
			FROM INFORMATION_SCHEMA.COLUMNS
			WHERE
				TABLE_NAME = @tableName AND TABLE_SCHEMA = 'WWI';

	
		-- Variaveis usadas para construir o procedure.
		DECLARE @colName VARCHAR(MAX);
		DECLARE @dataType VARCHAR(MAX);
		DECLARE @size VARCHAR(MAX);
		DECLARE @isPrimaryKey bit;
		DECLARE @isForeignKey bit;


		SET @params = '';
		SET @where = '';

		-- Percorre linha por linha para construir os parametros necessarios.
		OPEN Cols
			FETCH NEXT FROM Cols INTO @colName, @dataType, @size, @isPrimaryKey, @isForeignKey
			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Update pelos primary key.
				IF(@isPrimaryKey = 1)
				BEGIN
					SET @params = CASE WHEN @size IS NULL THEN @params + '@' + @colName + ' ' + @dataType + ',' ELSE @params + '@' + @colName + ' ' + @dataType + '('+@size+')'+',' END;
					SET @where = @where + @colName + '=@' +@colName + ' AND ';
				END
		
				FETCH NEXT FROM Cols INTO @colName, @dataType, @size, @isPrimaryKey, @isForeignKey
			END
		CLOSE Cols
		DEALLOCATE Cols

		SET @params = LEFT(@params, LEN(@params) - 1);
		SET @where = LEFT(@where, LEN(@where) - 4);



		-- Adiciona o texto para a contrução do procedure.
		SET @sql = '
			CREATE OR ALTER PROCEDURE WWI.'+@tableName+'_delete
			(
				' + @params + '
			)
			AS
			BEGIN TRY
				DELETE FROM WWI.' + @tableName + ' WHERE ' + @where + ';
			END TRY
			BEGIN CATCH
				EXEC Logs.sp_ErrorHandling
			END CATCH
		'
		EXEC(@sql)
	END TRY
	BEGIN CATCH
		EXEC Logs.sp_ErrorHandling
	END CATCH
END
GO

--- Apoio à monitorização
CREATE OR ALTER PROCEDURE WWI.sp_monitoring
AS
BEGIN
	BEGIN TRY
		DECLARE @date VARCHAR(50);
		set @date = FORMAT(GETDATE(), N'yyyy-MM-dd HH:mm');
		INSERT INTO WWI.Monitoring(TableName, ColumnName, DataType, MaxLength, IsNullable, IsIdentity, IsPrimaryKey,CreatedAt)
			SELECT
				o.name as 'Table Name',
				c.name as 'Column Name',
				t.Name as 'Data Type',
				c.max_length as 'Max Length',
				c.is_nullable as 'IsNullable',
				c.is_identity as 'IsIdentity',
				CASE WHEN EXISTS (
					SELECT 1
					FROM sys.index_columns ic
					JOIN sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id
					WHERE ic.object_id = c.object_id AND ic.column_id = c.column_id AND i.is_primary_key = 1
				) THEN 1 ELSE 0 END AS 'IsPrimaryKey',
				@date as dateinserts
			FROM sys.schemas s
				JOIN sys.all_objects o on s.schema_id=o.schema_id
				JOIN sys.all_columns c on c.object_id=o.object_id
				INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
			WHERE (s.name='WWI' or s.name='Logs') and type_desc='USER_TABLE';

		SELECT * FROM WWI.Monitoring ORDER BY CreatedAt DESC;
	END TRY
	BEGIN CATCH
		EXEC Logs.sp_ErrorHandling
	END CATCH
END
GO


CREATE OR ALTER VIEW WWI.LastMonitoring as
	SELECT * FROM WWI.Monitoring where CreatedAt=(SELECT MAX(CreatedAt) as latest_date FROM WWI.Monitoring);
GO

CREATE OR ALTER PROCEDURE WWI.sp_monitoringstorage
AS
BEGIN
	BEGIN TRY
		DECLARE @date VARCHAR(50);
		set @date = FORMAT(GETDATE(), N'yyyy-MM-dd HH:mm');

		INSERT INTO WWI.MonitoringStorage(TableName, ReservedSpace, UsedSpace, NumberOfRows, CreatedAt)
			SELECT
				OBJECT_NAME(t.object_id) as 'Table Name',
				sum(u.total_pages) * 8 as 'Total Reserved Space (KB)',
				sum(u.used_pages) * 8 as 'Total Used Space (KB)',
				max(p.rows) as 'Records Number',
				@date
			FROM
				sys.allocation_units u
				JOIN sys.partitions p on u.container_id = p.hobt_id
				JOIN sys.tables t on p.object_id = t.object_id
			WHERE
				t.schema_id = SCHEMA_ID('WWI') or t.schema_id = SCHEMA_ID('Logs') 
			GROUP BY
				t.object_id,
				OBJECT_NAME(t.object_id),
				u.type_desc

		  SELECT * FROM WWI.MonitoringStorage ORDER BY CreatedAt DESC;

	END TRY
	BEGIN CATCH
		EXEC Logs.sp_ErrorHandling
	END CATCH
END
GO

CREATE OR ALTER VIEW WWI.LastMonitoringStorage as
	SELECT * FROM WWI.MonitoringStorage where CreatedAt=(SELECT MAX(CreatedAt) as latest_date FROM WWI.MonitoringStorage);
GO