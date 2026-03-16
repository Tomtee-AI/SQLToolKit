-- Set full recovery (if not already)
ALTER DATABASE TestDB1 SET RECOVERY FULL;
ALTER DATABASE TestDB2 SET RECOVERY FULL;
GO

-- Take full and log backups
BACKUP DATABASE TestDB1 TO DISK = 'C:\Backup\TestDB1.bak' WITH FORMAT;
BACKUP LOG TestDB1 TO DISK = 'C:\Backup\TestDB1_log.trn';
BACKUP DATABASE TestDB2 TO DISK = 'C:\Backup\TestDB2.bak' WITH FORMAT;
BACKUP LOG TestDB2 TO DISK = 'C:\Backup\TestDB2_log.trn';
GO

-- Add databases to AG (if not added during create)
ALTER AVAILABILITY GROUP MyAG ADD DATABASE TestDB1;
ALTER AVAILABILITY GROUP MyAG ADD DATABASE TestDB2;
GO