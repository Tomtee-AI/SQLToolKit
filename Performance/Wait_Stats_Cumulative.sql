/*
    Wait Stats - Cumulative
    =========================================================================
    Purpose:    Shows cumulative wait statistics since last server restart
                or last wait stats clear (DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR)).
                Helps identify the primary sources of waits / bottlenecks.
    Author:     Thomas Thomasson (written with Grok)
    Compatible: SQL Server 2016+
    Usage:      Execute in SSMS / Azure Data Studio.
                Focus on high wait_time_sec values and high percentage.
    Notes:      Ignores common benign/idle waits.
                Data resets on restart or manual clear.
                Requires VIEW SERVER STATE permission.
    =========================================================================
*/

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

-- Total wait time across all waits (for percentage calculation)
DECLARE @TotalWaitTime bigint;

SELECT @TotalWaitTime = SUM(wait_time_ms)
FROM sys.dm_os_wait_stats
WHERE wait_time_ms > 0;

PRINT '================================================================================';
PRINT 'CUMULATIVE WAIT STATISTICS SINCE LAST RESTART / CLEAR';
PRINT '   Total wait time captured: ' + CONVERT(varchar(30), @TotalWaitTime / 1000.0 / 3600.0, 114) + ' hours';
PRINT '   Ordered by total wait time descending';
PRINT '================================================================================';

SELECT TOP 25
    wait_type AS WaitType
    ,waiting_tasks_count AS Waiting_Tasks_Count
    ,wait_time_ms / 1000.0 AS Wait_Time_Seconds
    ,wait_time_ms * 100.0 / @TotalWaitTime AS [%OfTotalWaitTime]
    ,signal_wait_time_ms / 1000.0 AS Signal_Wait_Seconds
    ,(wait_time_ms - signal_wait_time_ms) / 1000.0 AS Resource_Wait_Seconds
FROM sys.dm_os_wait_stats
WHERE wait_time_ms > 0
    AND wait_type NOT IN (
        'BROKER_EVENTHANDLER','BROKER_RECEIVE_WAITFOR','BROKER_TASK_STOP',
        'BROKER_TO_FLUSH','BROKER_TRANSMITTER','CHECKPOINT_QUEUE',
        'DBMIRROR_EVENTS_QUEUE','DBMIRRORING_CMD','DIRTY_PAGE_POLL',
        'FT_IFTS_SCHEDULER_IDLE_WAIT','FT_IFTSHC_MUTEX','HADR_CLUSAPI_CALL',
        'LAZYWRITER_SLEEP','LOGMGR_QUEUE','MEMORY_ALLOCATION_EXT',
        'ONDEMAND_TASK_QUEUE','PREEMPTIVE_HADR_LEASE_MECHANISM',
        'PREEMPTIVE_OS_GETPROCADDRESS','PREEMPTIVE_OS_AUTHENTICATIONOPS',
        'PREEMPTIVE_OS_CRYPTOACCOUNTS','PREEMPTIVE_OS_CRYPTACQUIRECONTEXT',
        'PREEMPTIVE_OS_DEVICEOPS','PREEMPTIVE_OS_QUERYREGISTRY',
        'PREEMPTIVE_OS_SERVICEOPS','PREEMPTIVE_OS_SQLCLRASSEMBLY',
        'PREEMPTIVE_OS_SQLCLRAUTHENTICATION','PREEMPTIVE_OS_SQLCLRHOST',
        'PREEMPTIVE_OS_SQLCLRHOSTTASK','PREEMPTIVE_OS_SQLCLRTASK',
        'PREEMPTIVE_OS_SQLCLRUNMANAGEDCALLER','PREEMPTIVE_OS_SQLCLRUSER',
        'PREEMPTIVE_OS_SQLSECURITY','PREEMPTIVE_OS_VSS',
        'PREEMPTIVE_XE_CALLBACKEXECUTE','PREEMPTIVE_XE_DISPATCHER',
        'PREEMPTIVE_XE_GETTARGETSTATE','PREEMPTIVE_XE_SESSIONCOMMIT',
        'PREEMPTIVE_XE_TARGETINIT','PREEMPTIVE_XE_TARGETPREPARE',
        'PWAIT_ALL_COMPONENTS_INITIALIZED','PWAIT_DIRECTLOGCONSUMER_GETNEXT',
        'PWAIT_EXTSTORE_CLEANUP','PWAIT_HADR_CHANGE_NOTIFICATIONS',
        'PWAIT_HADR_OFFLINE_COMPLETED','PWAIT_HADR_WORKER',
        'PWAIT_HA_FAILOVER_COMPLETED','PWAIT_HA_FAILOVER_COMPLETED',
        'REPL_CACHE_ACCESS','REPLICA_WRITE','REQUEST_FOR_DEADLOCK_SEARCH',
        'SLEEP_BPOOL_FLUSH','SLEEP_DBSTARTUP','SLEEP_DCOMSTARTUP',
        'SLEEP_MASTERDBREADY','SLEEP_MASTERMDREADY','SLEEP_MASTERUPGRADED',
        'SLEEP_MSDBSTARTUP','SLEEP_SYSTEMTASK','SLEEP_TASK',
        'SLEEP_TEMPDBSTARTUP','SQLTRACE_BUFFER_FLUSH','SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
        'WAIT_XTP_HOST_WAIT','WAIT_XTP_OFFLINE_CKPT_NEW_LOG','WAIT_XTP_CKPT_CLOSE',
        'XE_DISPATCHER_JOIN','XE_DISPATCHER_WAIT','XE_LIVE_TARGET_TVF',
        'XE_TIMER_EVENT'
    )
ORDER BY wait_time_ms DESC;


PRINT '================================================================================';
PRINT 'TOP 10 RESOURCE WAITS (wait_time_ms - signal_wait_time_ms)';
PRINT '   (Pure resource contention - disk, memory, locks, etc.)';
PRINT '================================================================================';

SELECT TOP 10
    wait_type AS WaitType
    ,(wait_time_ms - signal_wait_time_ms) / 1000.0 AS Resource_Wait_Seconds
    ,signal_wait_time_ms / 1000.0 AS Signal_Wait_Seconds
    ,wait_time_ms / 1000.0 AS Total_Wait_Seconds
    ,waiting_tasks_count AS Waiting_Tasks_Count
FROM sys.dm_os_wait_stats
WHERE wait_time_ms > signal_wait_time_ms
    AND wait_type NOT IN (
        'BROKER_EVENTHANDLER','BROKER_RECEIVE_WAITFOR','BROKER_TASK_STOP',
        'BROKER_TO_FLUSH','BROKER_TRANSMITTER','CHECKPOINT_QUEUE',
        'LAZYWRITER_SLEEP','LOGMGR_QUEUE','REPL_CACHE_ACCESS',
        'REPLICA_WRITE','REQUEST_FOR_DEADLOCK_SEARCH','SLEEP_TASK',
        'SLEEP_SYSTEMTASK','SQLTRACE_BUFFER_FLUSH','WAITFOR',
        'XE_DISPATCHER_WAIT','XE_TIMER_EVENT'
    )
ORDER BY (wait_time_ms - signal_wait_time_ms) DESC;


PRINT '================================================================================';
PRINT 'Wait Stats - Cumulative Complete';
PRINT 'High wait times may indicate CPU pressure, disk I/O, memory grants, blocking, etc.';
PRINT 'Cross-reference with sp_BlitzFirst or Perfmon counters for deeper diagnosis.';
PRINT '================================================================================';