/*
    Backup Status Report
    =========================================================================
    Purpose:    Comprehensive report on recent database backups (full, differential, log)
                Highlights missing/recent backups, sizes, durations, and potential issues
    Author:     Thomas Thomasson (written with Grok)
    Compatible: SQL Server 2016+
    Usage:      Execute in SSMS / Azure Data Studio.
                Review summary and detail sections for backup health.
    =========================================================================
    Features:
      - Summary: Last backup per database + age in hours/days
      - Detail: Most recent backup per type with size, duration, location
      - Gaps: Databases without recent full backup (configurable threshold)
      - Backup History Age: How far back the msdb history goes
*/

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE 
    @DaysToCheck int = 14,              -- How far back to look for backup history
    @FullBackupWarningHours int = 36,   -- Alert if no full backup in X hours
    @DiffBackupWarningHours int = 48,   -- Alert if no differential in X hours (only relevant for FULL recovery)
    @LogBackupWarningHours int = 4;     -- Alert if no log backup in X hours (FULL/BULK_LOGGED only)

PRINT '================================================================================';
PRINT 'BACKUP STATUS REPORT - ' + CONVERT(varchar(20), GETDATE(), 120);
PRINT '================================================================================';

PRINT '1. BACKUP COVERAGE SUMMARY (Most Recent per Database)';
PRINT '   (Age in hours / days - WARNING if too old)';
PRINT '================================================================================';

WITH LastBackupPerDB AS (
    SELECT 
        d.name AS DatabaseName
        ,d.recovery_model_desc AS RecoveryModel
        ,MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END) AS LastFull
        ,MAX(CASE WHEN bs.type = 'I' THEN bs.backup_finish_date END) AS LastDiff
        ,MAX(CASE WHEN bs.type = 'L' THEN bs.backup_finish_date END) AS LastLog
        ,DATEDIFF(HOUR, MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END), GETDATE()) AS HoursSinceFull
        ,DATEDIFF(HOUR, MAX(CASE WHEN bs.type = 'I' THEN bs.backup_finish_date END), GETDATE()) AS HoursSinceDiff
        ,DATEDIFF(HOUR, MAX(CASE WHEN bs.type = 'L' THEN bs.backup_finish_date END), GETDATE()) AS HoursSinceLog
    FROM sys.databases d
    LEFT JOIN msdb.dbo.backupset bs ON bs.database_name = d.name
        AND bs.backup_finish_date > DATEADD(DAY, -@DaysToCheck, GETDATE())
    WHERE d.source_database_id IS NULL          -- exclude snapshots
        AND d.name NOT IN ('tempdb', 'model')   -- usually not backed up
    GROUP BY d.name, d.recovery_model_desc
)
SELECT
    DatabaseName
    ,RecoveryModel
    ,LastFull AS [Last Full Backup]
    ,CASE 
        WHEN HoursSinceFull IS NULL THEN 'NEVER'
        WHEN HoursSinceFull > @FullBackupWarningHours THEN 'WARNING: ' + CAST(HoursSinceFull AS varchar(10)) + ' hrs'
        ELSE CAST(HoursSinceFull AS varchar(10)) + ' hrs'
     END AS [Full Age]
    ,LastDiff AS [Last Diff Backup]
    ,CASE 
        WHEN RecoveryModel <> 'FULL' THEN 'N/A'
        WHEN HoursSinceDiff IS NULL THEN 'NEVER'
        WHEN HoursSinceDiff > @DiffBackupWarningHours THEN 'WARNING: ' + CAST(HoursSinceDiff AS varchar(10)) + ' hrs'
        ELSE CAST(HoursSinceDiff AS varchar(10)) + ' hrs'
     END AS [Diff Age]
    ,LastLog AS [Last Log Backup]
    ,CASE 
        WHEN RecoveryModel <> 'FULL' AND RecoveryModel <> 'BULK_LOGGED' THEN 'N/A'
        WHEN HoursSinceLog IS NULL THEN 'NEVER'
        WHEN HoursSinceLog > @LogBackupWarningHours THEN 'WARNING: ' + CAST(HoursSinceLog AS varchar(10)) + ' hrs'
        ELSE CAST(HoursSinceLog AS varchar(10)) + ' hrs'
     END AS [Log Age]
FROM LastBackupPerDB
ORDER BY 
    CASE WHEN HoursSinceFull > @FullBackupWarningHours OR HoursSinceFull IS NULL THEN 0 ELSE 1 END
    ,DatabaseName;


PRINT '================================================================================';
PRINT '2. MOST RECENT BACKUP DETAILS (Last 30 days)';
PRINT '   (Includes backup size, duration, file location)';
PRINT '================================================================================';

SELECT TOP 100
    bs.database_name AS DatabaseName
    ,CASE bs.type 
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Log'
        ELSE bs.type 
     END AS BackupType
    ,bs.backup_start_date AS StartTime
    ,bs.backup_finish_date AS FinishTime
    ,DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) / 60.0 AS DurationMinutes
    ,CONVERT(decimal(12,2), bs.backup_size / 1024.0 / 1024.0 / 1024.0) AS SizeGB
    ,bmf.physical_device_name AS BackupFilePath
    ,bs.user_name AS PerformedBy
FROM msdb.dbo.backupset bs
INNER JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.backup_finish_date > DATEADD(DAY, -30, GETDATE())
    AND bs.type IN ('D','I','L')
ORDER BY bs.backup_finish_date DESC;


PRINT '================================================================================';
PRINT '3. DATABASES WITH POTENTIAL BACKUP GAPS';
PRINT '   (No full backup in last ' + CAST(@FullBackupWarningHours/24 AS varchar(5)) + ' days, or no log in last ' + CAST(@LogBackupWarningHours AS varchar(5)) + ' hrs)';
PRINT '================================================================================';

SELECT
    d.name AS DatabaseName
    ,d.recovery_model_desc AS RecoveryModel
    ,COALESCE(
        (SELECT MAX(backup_finish_date) FROM msdb.dbo.backupset 
         WHERE database_name = d.name AND type = 'D'), 
        '1900-01-01') AS LastFullBackup
    ,DATEDIFF(DAY, 
        COALESCE((SELECT MAX(backup_finish_date) FROM msdb.dbo.backupset 
                  WHERE database_name = d.name AND type = 'D'), '1900-01-01'), 
        GETDATE()) AS DaysSinceLastFull
FROM sys.databases d
WHERE d.source_database_id IS NULL
    AND d.name NOT IN ('master','model','msdb','tempdb')
    AND (
        -- No full backup ever or too old
        NOT EXISTS (SELECT 1 FROM msdb.dbo.backupset bs 
                    WHERE bs.database_name = d.name AND bs.type = 'D'
                      AND bs.backup_finish_date > DATEADD(HOUR, -@FullBackupWarningHours, GETDATE()))
        OR
        -- FULL recovery but no recent log
        (d.recovery_model_desc IN ('FULL','BULK_LOGGED')
         AND NOT EXISTS (SELECT 1 FROM msdb.dbo.backupset bs 
                         WHERE bs.database_name = d.name AND bs.type = 'L'
                           AND bs.backup_finish_date > DATEADD(HOUR, -@LogBackupWarningHours, GETDATE())))
    )
ORDER BY DaysSinceLastFull DESC, DatabaseName;


PRINT '================================================================================';
PRINT '4. BACKUP HISTORY RETENTION IN MSDB';
PRINT '   (How far back we have records - important for point-in-time recovery)';
PRINT '================================================================================';

SELECT 
    MIN(backup_start_date) AS OldestBackupRecord
    ,MAX(backup_start_date) AS NewestBackupRecord
    ,DATEDIFF(DAY, MIN(backup_start_date), GETDATE()) AS DaysOfHistory
FROM msdb.dbo.backupset;


PRINT '================================================================================';
PRINT 'Backup Status Report Complete';
PRINT 'Review any WARNING entries or gaps above.';
PRINT '================================================================================';