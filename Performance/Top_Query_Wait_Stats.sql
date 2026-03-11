/*
    Top Queries by Wait Stats
    =========================================================================
    Purpose:    Shows queries/sessions that are currently waiting or have
                accumulated the most wait time (real-time + session-level).
                Great for spotting what's causing high waits RIGHT NOW.
    Author:     Thomas Thomasson (written with Grok)
    Compatible: SQL Server 2016+
    Usage:      Run in SSMS / Azure Data Studio.
                Requires VIEW SERVER STATE permission.
    Notes:      - Current waits from dm_os_waiting_tasks + dm_exec_requests
                - Session waits from dm_exec_session_wait_stats (resets on disconnect)
                - Ignores benign/idle waits
    =========================================================================
*/

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

PRINT '================================================================================';
PRINT 'CURRENTLY WAITING TASKS / QUERIES (Real-time blockers & high waits)';
PRINT '   (Ordered by wait duration descending)';
PRINT '================================================================================';

SELECT TOP 20
    wt.session_id AS SessionID
    ,wt.wait_type AS WaitType
    ,wt.wait_duration_ms / 1000.0 AS Wait_Seconds
    ,wt.blocking_session_id AS BlockingSessionID
    ,r.status AS RequestStatus
    ,r.wait_time / 1000.0 AS Request_Wait_Seconds
    ,r.cpu_time AS CpuTime_ms
    ,r.logical_reads AS LogicalReads
    ,SUBSTRING(
        st.text
        ,(r.statement_start_offset / 2) + 1
        ,((CASE 
            WHEN r.statement_end_offset = -1 THEN DATALENGTH(st.text) 
            ELSE r.statement_end_offset 
           END - r.statement_start_offset) / 2) + 1
     ) AS Query_Text
    ,DB_NAME(r.database_id) AS DatabaseName
FROM sys.dm_os_waiting_tasks wt
INNER JOIN sys.dm_exec_requests r 
    ON wt.session_id = r.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE wt.wait_duration_ms > 0
    AND wt.wait_type NOT IN (
        'BROKER_EVENTHANDLER','BROKER_RECEIVE_WAITFOR','BROKER_TASK_STOP',
        'BROKER_TO_FLUSH','BROKER_TRANSMITTER','CHECKPOINT_QUEUE',
        'LAZYWRITER_SLEEP','LOGMGR_QUEUE','SLEEP_TASK','SLEEP_SYSTEMTASK',
        'SQLTRACE_BUFFER_FLUSH','WAITFOR','XE_DISPATCHER_WAIT','XE_TIMER_EVENT'
    )
ORDER BY wt.wait_duration_ms DESC;


PRINT '================================================================================';
PRINT 'SESSIONS WITH HIGHEST ACCUMULATED WAIT TIME (dm_exec_session_wait_stats)';
PRINT '   (Cumulative waits per session - useful for long-lived connections)';
PRINT '================================================================================';

WITH SessionWaits AS (
    SELECT 
        session_id
        ,SUM(wait_time_ms) AS Total_Wait_ms
        ,SUM(signal_wait_time_ms) AS Total_Signal_Wait_ms
        ,SUM(waiting_tasks_count) AS Total_Wait_Tasks
    FROM sys.dm_exec_session_wait_stats
    GROUP BY session_id
)
SELECT TOP 20
    sw.session_id AS SessionID
    ,sw.Total_Wait_ms / 1000.0 AS Total_Wait_Seconds
    ,(sw.Total_Wait_ms - sw.Total_Signal_Wait_ms) / 1000.0 AS Resource_Wait_Seconds
    ,sw.Total_Signal_Wait_ms / 1000.0 AS Signal_Wait_Seconds
    ,sw.Total_Wait_Tasks AS Wait_Tasks_Count
    ,s.login_name AS LoginName
    ,s.program_name AS ProgramName
    ,s.host_name AS HostName
    ,DB_NAME(r.database_id) AS CurrentDB
    ,SUBSTRING(
        st.text
        ,(r.statement_start_offset / 2) + 1
        ,((CASE 
            WHEN r.statement_end_offset = -1 THEN DATALENGTH(st.text) 
            ELSE r.statement_end_offset 
           END - r.statement_start_offset) / 2) + 1
     ) AS Current_Query_Text
FROM SessionWaits sw
INNER JOIN sys.dm_exec_sessions s ON sw.session_id = s.session_id
LEFT JOIN sys.dm_exec_requests r ON sw.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE sw.session_id > 50                        -- exclude system sessions
    AND sw.Total_Wait_ms > 0
ORDER BY sw.Total_Wait_ms DESC;


PRINT '================================================================================';
PRINT 'Top Queries by Wait Stats Complete';
PRINT 'High waits here often point to blocking (LCK), I/O (PAGEIOLATCH), CPU pressure (SOS_SCHEDULER_YIELD),';
PRINT 'or parallelism (CXPACKET). Cross-check with sp_WhoIsActive or Query Store for deeper context.';
PRINT '================================================================================';