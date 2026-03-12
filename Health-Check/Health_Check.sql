/*
    SQL Server Instance Health Check - Comprehensive
    =========================================================================
    Purpose:    Quick overview of SQL Server instance and database health
    Author:     Tomtee.eth (customized for DBA Toolkit)
    Compatible: SQL Server 2016+
    Usage:      Execute in SSMS / Azure Data Studio. Review warnings in red/orange.
    =========================================================================
    Sections:
      1. Server & Instance Information (now includes auth mode, port, forced encryption + cert)
      2. Database Overview (now includes Containment + TDE status)
      3. Disk Space (Data & Log files)
      4. Memory & Page Life Expectancy
      5. CPU & Wait Stats Snapshot
      6. Backup Status (Last Full/Diff/Log backups)
      7. SQL Agent Job Failures (Last 24h)
      8. Quick Red Flags (Blocking, Long-Running, Suspect DBs)
*/

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

PRINT '================================================================================';
PRINT '1. SERVER & INSTANCE INFORMATION';
PRINT '   (Includes authentication mode, listener port, forced encryption status)';
PRINT '================================================================================';

SELECT
    @@SERVERNAME AS [ServerName\Instance]
    ,SERVERPROPERTY('MachineName') AS [WindowsServerName]
    ,SERVERPROPERTY('ServerName') AS [SQLServerInstanceName]
    ,SERVERPROPERTY('Edition') AS [Edition]
    ,SERVERPROPERTY('ProductVersion') AS [ProductVersion]
    ,SERVERPROPERTY('ProductLevel') AS [ProductLevel]      -- RTM/SP/CU
    ,SERVERPROPERTY('ProductUpdateLevel') AS [CU_Level]
    ,SERVERPROPERTY('Collation') AS [ServerCollation]
    ,@@VERSION AS [FullVersionString]
    ,sqlserver_start_time AS [SQLServerStarted]
    ,DATEDIFF(DAY, sqlserver_start_time, GETDATE()) AS [DaysUptime]
    ,CASE 
        WHEN CONVERT(INT, SERVERPROPERTY('IsClustered')) = 1 THEN 'Clustered'
        ELSE 'Standalone'
    END AS [ClusterStatus]
    ,CASE 
        WHEN CONVERT(INT, SERVERPROPERTY('IsHadrEnabled')) = 1 THEN 'AlwaysOn Enabled'
        ELSE 'AlwaysOn Not Enabled'
    END AS [AlwaysOnStatus]
    ,CASE SERVERPROPERTY('IsIntegratedSecurityOnly')
        WHEN 1 THEN 'Windows Authentication only'
        WHEN 0 THEN 'Mixed Mode (Windows + SQL Authentication)'
        ELSE 'Unknown'
    END AS [AuthenticationMode]
    ,(SELECT TOP 1 
        CAST(port AS varchar(10)) + ' (' + type_desc + ')' 
      FROM sys.dm_tcp_listener_states 
      WHERE state_desc = 'ONLINE' 
      ORDER BY port) AS [ListenerPort_TCP]
    ,CASE 
        WHEN CONVERT(bit, SERVERPROPERTY('IsEncrypted')) = 1 
             THEN 'Forced Encryption ENABLED'
        ELSE 'Forced Encryption DISABLED'
     END AS [ConnectionEncryptionStatus]
    ,CASE 
        WHEN CONVERT(bit, SERVERPROPERTY('IsEncrypted')) = 1 
             THEN 'Certificate details visible only in SQL Server Configuration Manager (Protocols → Certificate tab) or registry (HKLM\...\SuperSocketNetLib)'
        ELSE 'N/A'
     END AS [EncryptionCertificateNote]
FROM sys.dm_os_sys_info;

PRINT '================================================================================';
PRINT '2. DATABASE OVERVIEW (Size, Status, Recovery Model, Containment, TDE)';
PRINT '   (Contained = partially or fully contained database)';
PRINT '   (Contained AG = database in a contained availability group - SQL 2022+)';
PRINT '   (TDE = Transparent Data Encryption enabled + certificate name)';
PRINT '================================================================================';

SELECT
    DB_NAME(d.database_id) AS [DatabaseName]
    ,d.state_desc AS [State]
    ,d.recovery_model_desc AS [RecoveryModel]
    ,d.compatibility_level AS [CompatLevel]
    ,CASE d.containment_desc
        WHEN 'NONE' THEN 'Not Contained'
        WHEN 'PARTIAL' THEN 'Partially Contained'
        WHEN 'FULL' THEN 'Fully Contained'
        ELSE d.containment_desc
    END AS [ContainmentStatus]
    ,CASE 
        WHEN ag.is_contained = 1 THEN 'Yes - Contained AG: ' + ag.name
        WHEN ag.name IS NOT NULL THEN 'Yes - Standard AG: ' + ag.name
        ELSE 'No'
     END AS [AvailabilityGroup]
    ,CASE 
        WHEN ed.database_id IS NOT NULL THEN 'ENABLED - Cert: ' + c.name
        ELSE 'Disabled'
     END AS [TransparentDataEncryption]
    ,CONVERT(DECIMAL(12,2), 
        SUM(CASE WHEN mf.type_desc = 'ROWS' THEN mf.size * 8.0 / 1024 ELSE 0 END)) AS [DataSizeGB]
    ,CONVERT(DECIMAL(12,2), 
        SUM(CASE WHEN mf.type_desc = 'LOG' THEN mf.size * 8.0 / 1024 ELSE 0 END)) AS [LogSizeGB]
    ,COUNT(*) AS [FileCount]
FROM sys.databases d
INNER JOIN sys.master_files mf ON d.database_id = mf.database_id
LEFT JOIN sys.availability_replicas ar 
    ON EXISTS (
        SELECT 1 
        FROM sys.dm_hadr_availability_replica_states hars
        WHERE hars.replica_id = ar.replica_id
          AND hars.is_local = 1
    )
LEFT JOIN sys.availability_groups ag ON ar.group_id = ag.group_id
LEFT JOIN sys.dm_database_encryption_keys ed ON d.database_id = ed.database_id
LEFT JOIN sys.certificates c ON ed.encryptor_thumbprint = c.thumbprint
WHERE d.source_database_id IS NULL          -- exclude snapshots
GROUP BY 
    d.database_id
    ,d.state_desc
    ,d.recovery_model_desc
    ,d.compatibility_level
    ,d.containment_desc
    ,ag.name
    ,ag.is_contained
    ,ed.database_id
    ,c.name
ORDER BY DataSizeGB DESC;


PRINT '================================================================================';
PRINT '3. DISK SPACE USAGE (Data & Log Files)';
PRINT '================================================================================';

;WITH FileSizeCTE AS (
    SELECT
        DB_NAME(mf.database_id) AS DatabaseName
        ,mf.type_desc AS FileType
        ,mf.physical_name AS PhysicalFile
        ,mf.size * 8.0 / 1024 AS SizeMB
        ,mf.max_size * 8.0 / 1024 AS MaxSizeMB
        ,vs.volume_mount_point AS Drive
        ,CONVERT(DECIMAL(20,2), vs.available_bytes / 1024.0 / 1024.0) AS FreeSpaceGB
        ,CONVERT(DECIMAL(20,2), vs.total_bytes / 1024.0 / 1024.0) AS TotalSpaceGB
    FROM sys.master_files mf
    CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs
    WHERE mf.database_id > 4
)
SELECT
    Drive
    ,DatabaseName
    ,FileType
    ,PhysicalFile
    ,CONVERT(DECIMAL(12,2), SizeMB / 1024) AS SizeGB
    ,CONVERT(DECIMAL(12,2), FreeSpaceGB) AS FreeGB
    ,CONVERT(DECIMAL(5,2), FreeSpaceGB * 100.0 / NULLIF(TotalSpaceGB,0)) AS [%Free]
    ,CASE 
        WHEN FreeSpaceGB < 5 THEN 'CRITICAL'
        WHEN FreeSpaceGB < 20 THEN 'WARNING'
        ELSE 'OK'
    END AS Alert
FROM FileSizeCTE
ORDER BY Drive, DatabaseName, FileType;


PRINT '================================================================================';
PRINT '4. MEMORY & PAGE LIFE EXPECTANCY';
PRINT '================================================================================';

SELECT
    total_physical_memory_kb / 1024 AS [TotalRAM_MB]
    ,available_physical_memory_kb / 1024 AS [AvailableRAM_MB]
    ,system_memory_state_desc AS [MemoryPressureState]
    ,(SELECT cntr_value 
      FROM sys.dm_os_performance_counters 
      WHERE counter_name = 'Page life expectancy'
      AND object_name LIKE '%:Buffer Manager%') AS [PageLifeExpectancy_sec]
    ,CASE 
        WHEN (SELECT cntr_value FROM sys.dm_os_performance_counters 
              WHERE counter_name = 'Page life expectancy'
              AND object_name LIKE '%:Buffer Manager%') < 300 THEN 'LOW - Investigate'
        ELSE 'Acceptable'
    END AS PLE_Status
FROM sys.dm_os_sys_memory;


PRINT '================================================================================';
PRINT '5. TOP 10 WAITS (Snapshot - Last ~1-5 min)';
PRINT '================================================================================';

SELECT TOP 10
    wait_type
    ,waiting_tasks_count
    ,wait_time_ms / 1000.0 AS wait_time_sec
    ,max_wait_time_ms / 1000.0 AS max_wait_sec
    ,signal_wait_time_ms / 1000.0 AS signal_wait_sec
    ,(wait_time_ms - signal_wait_time_ms) / 1000.0 AS resource_wait_sec
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
    'BROKER_EVENTHANDLER','BROKER_RECEIVE_WAITFOR','BROKER_TASK_STOP',
    'BROKER_TO_FLUSH','BROKER_TRANSMITTER','CHECKPOINT_QUEUE',
    'FT_IFTS_SCHEDULER_IDLE_WAIT','LAZYWRITER_SLEEP','LOGMGR_QUEUE',
    'REPL_CACHE_ACCESS','REPLICA_WRITE','REQUEST_FOR_DEADLOCK_SEARCH',
    'SLEEP_TASK','SLEEP_SYSTEMTASK','SQLTRACE_BUFFER_FLUSH',
    'WAITFOR','XE_DISPATCHER_WAIT','XE_TIMER_EVENT'
)
ORDER BY wait_time_ms DESC;


PRINT '================================================================================';
PRINT '6. BACKUP STATUS (Last 7 Days - Most Recent per DB)';
PRINT '================================================================================';

;WITH LastBackup AS (
    SELECT
        database_name
        ,backup_start_date
        ,backup_finish_date
        ,type
        ,backup_size / 1024.0 / 1024.0 / 1024.0 AS BackupSizeGB
        ,ROW_NUMBER() OVER (PARTITION BY database_name, type ORDER BY backup_start_date DESC) AS rn
    FROM msdb.dbo.backupset
    WHERE backup_start_date > DATEADD(DAY, -7, GETDATE())
      AND type IN ('D','I','L')
)
SELECT
    database_name AS [Database]
    ,MAX(CASE WHEN type = 'D' THEN backup_finish_date END) AS [LastFull]
    ,MAX(CASE WHEN type = 'I' THEN backup_finish_date END) AS [LastDiff]
    ,MAX(CASE WHEN type = 'L' THEN backup_finish_date END) AS [LastLog]
    ,CONVERT(DECIMAL(12,2), MAX(CASE WHEN type = 'D' THEN BackupSizeGB END)) AS [LastFullSizeGB]
FROM LastBackup
WHERE rn = 1
GROUP BY database_name
ORDER BY database_name;


PRINT '================================================================================';
PRINT '7. SQL AGENT JOBS - Failures in Last 24 Hours';
PRINT '================================================================================';

SELECT
    j.name AS [JobName]
    ,h.run_date
    ,h.run_time
    ,h.message
    ,CASE h.run_status 
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
     END AS [Status]
FROM msdb.dbo.sysjobs j
INNER JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
WHERE h.step_id = 0
  AND h.run_status <> 1
  AND msdb.dbo.agent_datetime(h.run_date, h.run_time) > DATEADD(HOUR, -24, GETDATE())
ORDER BY h.run_date DESC, h.run_time DESC;


PRINT '================================================================================';
PRINT '8. QUICK RED FLAGS';
PRINT '================================================================================';

-- Suspect / Offline / Emergency databases
SELECT
    name AS [SuspectOrProblemDB]
    ,state_desc AS [StateDesc] 
FROM sys.databases 
WHERE state NOT IN (0,1,5,7);

-- Blocking sessions (> 5 sec)
IF EXISTS (SELECT 1 FROM sys.dm_exec_requests WHERE blocking_session_id <> 0 AND wait_time > 5000)
    SELECT
        r.session_id AS BlockedSession
        ,r.blocking_session_id AS BlockingSession
        ,r.wait_type
        ,r.wait_time / 1000 AS WaitSeconds
        ,DB_NAME(r.database_id) AS DatabaseName
        ,SUBSTRING(st.text, r.statement_start_offset/2 + 1, 
                  ((CASE WHEN r.statement_end_offset = -1 
                         THEN LEN(CONVERT(nvarchar(max), st.text)) * 2 
                         ELSE r.statement_end_offset 
                    END - r.statement_start_offset)/2) + 1) AS BlockedQuery
    FROM sys.dm_exec_requests r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
    WHERE r.blocking_session_id <> 0
      AND r.wait_time > 5000;
ELSE 
    SELECT 'No blocking > 5 seconds' AS Status;

PRINT '================================================================================';
PRINT 'Health Check Complete - Review any WARNING/CRITICAL items above.';
PRINT '================================================================================';
