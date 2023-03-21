USE WWIGlobal;

ALTER DATABASE WWIGlobal SET RECOVERY FULL WITH NO_WAIT;

-- Backup Full Backup - semanalmente
BACKUP DATABASE WWIGlobal
TO DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalFullBackup.bak'
WITH NOFORMAT, INIT,
NAME = 'WWIGlobal - Full Backup.',
SKIP, NOREWIND, NOUNLOAD, STATS = 10;

-- Backup Differential - diariamente
BACKUP DATABASE WWIGlobal
TO DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalDifferentialBackup.bak'
WITH DIFFERENTIAL,
NOFORMAT, INIT,
NAME = 'WWIGlobal - Full Differential.',
SKIP, NOREWIND, NOUNLOAD, STATS = 10;

-- Backup log de transações - 15 Minutos
BACKUP LOG WWIGlobal
TO DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalLogBackup.trn' 
WITH NOFORMAT,
INIT,
NAME = 'WWIGlobal - Logs Backup.',
SKIP, NOREWIND, NOUNLOAD, STATS = 10;

-- RESTAURAR BACKUP

-- Fazer Backup do Tail Log
BACKUP LOG WWIGlobal TO DISK='C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalTailLogBackup.trn'
WITH NO_TRUNCATE, INIT;


-- Restaurar os backups
USE [master];

DECLARE @kill varchar(8000) = '';  
SELECT @kill = @kill + 'kill ' + CONVERT(varchar(5), session_id) + ';'  
FROM sys.dm_exec_sessions  
WHERE database_id = DB_ID('WWIGlobal') AND session_id <> @@SPID;
EXEC(@kill);

RESTORE DATABASE WWIGlobal FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalFullBackup.bak' WITH NORECOVERY

RESTORE DATABASE WWIGlobal FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalDifferentialBackup.bak' WITH NORECOVERY

RESTORE LOG WWIGlobal FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalLogBackup.trn' WITH NORECOVERY

RESTORE LOG WWIGlobal FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalTailLogBackup.trn' WITH RECOVERY

--- Versão otimizada diferenciando as tabelas de leitura.
-- REALIZAR BACKUPS

-- BACKUP FULL 2 Semanas.
BACKUP DATABASE WWIGlobal
TO DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalFullBackup.bak'
WITH NOFORMAT, INIT,
NAME = 'WWIGlobal - Full Backup.',
SKIP, NOREWIND, NOUNLOAD, STATS = 10;

-- Backup FULL Somente do filegroup Write. Semanalmente
BACKUP DATABASE WWIGlobal
FILEGROUP = 'WriteDataGroup'
TO DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalFullWriteDataGroupBackup.bak'
WITH NOFORMAT, INIT,
NAME = 'WWIGlobal - Full Backup.',
SKIP, NOREWIND, NOUNLOAD, STATS = 10;

-- Backup Differential - diariamente
BACKUP DATABASE WWIGlobal
FILEGROUP = 'WriteDataGroup'
TO DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalDifferentialWriteDataGroupBackup.bak'
WITH DIFFERENTIAL,
NOFORMAT, INIT,
NAME = 'WWIGlobal - Full Differential.',
SKIP, NOREWIND, NOUNLOAD, STATS = 10;

-- Backup Differential - Semanalmente
BACKUP DATABASE WWIGlobal
FILEGROUP = 'ReadDataGroup'
TO DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalDifferentialReadDataGroupBackup.bak'
WITH DIFFERENTIAL,
NOFORMAT, INIT,
NAME = 'WWIGlobal - Full Differential.',
SKIP, NOREWIND, NOUNLOAD, STATS = 10;


-- Backup log de transações - 15 Minutos
BACKUP LOG WWIGlobal
TO DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalLogBackup.trn' 
WITH NOFORMAT,
INIT,
NAME = 'WWIGlobal - Logs Backup.',
SKIP, NOREWIND, NOUNLOAD, STATS = 10;

-- Recuperação
BACKUP LOG WWIGlobal TO DISK='C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalTailLogBackup.trn'
WITH NO_TRUNCATE, INIT;

USE [master];

DECLARE @kill2 varchar(8000) = '';  
SELECT @kill2 = @kill2 + 'kill ' + CONVERT(varchar(5), session_id) + ';'  
FROM sys.dm_exec_sessions  
WHERE database_id = DB_ID('WWIGlobal') AND session_id <> @@SPID;
EXEC(@kill2);

-- Restaurar Full Backup.
RESTORE DATABASE WWIGlobal FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalFullBackup.bak' WITH NORECOVERY

-- Restaurar Full Backup do WriteGroup
RESTORE DATABASE WWIGlobal FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalFullWriteDataGroupBackup.bak' WITH NORECOVERY

-- Restaurar Differential Backup WriteGroup
RESTORE DATABASE WWIGlobal FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalDifferentialWriteDataGroupBackup.bak' WITH NORECOVERY

-- Restaurar Differential Backup do ReadGroup
RESTORE DATABASE WWIGlobal FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalDifferentialReadDataGroupBackup.bak' WITH NORECOVERY

-- Restaurar Logs Backup
RESTORE DATABASE WWIGlobal FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalLogBackup.trn' WITH NORECOVERY

-- Restaurar Logs Backup
RESTORE DATABASE WWIGlobal FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\WWIGlobalTailLogBackup.trn' WITH RECOVERY