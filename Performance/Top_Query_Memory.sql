/*
    Top Queries by Memory Usage
    =========================================================================
    Purpose:    Identifies queries consuming or requesting the most memory
                - Cached plans: total/avg memory grants over lifetime
                - Current executions: real-time memory grants & waits
    Author:     Thomas Thomasson (written with Grok)
    Compatible: SQL Server 2016+
    Usage:      Run in SSMS / Azure Data Studio.
                Requires VIEW SERVER STATE permission.
    Notes:      Memory grants are mainly for SORT, HASH JOIN, etc.
                High requested but low granted = RESOURCE_SEMAPHORE waits.
    =========================================================================
*/

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

PRINT '================================================================================';
PRINT 'TOP CACHED QUERIES BY TOTAL MEMORY GRANTED (Cumulative since cache entry)';
PRINT '   (Queries that requested the most memory over all executions)';
PRINT '================================================================================';

SELECT TOP 20
    total_grant_kb / 1024.0 AS Total_Grant_MB
    ,max_grant_kb / 1024.0 AS Max_Grant_MB
    ,total_grant_kb / 1024.0 / NULLIF(execution_count, 0) AS Avg_Grant_MB_per_exec
    ,execution_count AS Execution_Count
    ,last_execution_time AS Last_Execution
    ,SUBSTRING(
        st.text
        ,(qs.statement_start_offset / 2) + 1
        ,((CASE 
            WHEN qs.statement_end_offset = -1 THEN DATALENGTH(st.text) 
            ELSE qs.statement_end_offset 
           END - qs.statement_start_offset) / 2) + 1
     ) AS Query_Text
    ,DB_NAME(st.dbid) AS DatabaseName
    ,OBJECT_NAME(st.objectid, st.dbid) AS ObjectName
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE total_grant_kb > 0
ORDER BY total_grant_kb DESC;


PRINT '================================================================================';
PRINT 'TOP CACHED QUERIES BY AVERAGE MEMORY GRANT PER EXECUTION';
PRINT '   (Most memory-hungry per run - even if rare)';
PRINT '================================================================================';

SELECT TOP 20
    total_grant_kb / 1024.0 / NULLIF(execution_count, 0) AS Avg_Grant_MB_per_exec
    ,total_grant_kb / 1024.0 AS Total_Grant_MB
    ,max_grant_kb / 1024.0 AS Max_Grant_MB
    ,execution_count AS Execution_Count
    ,last_execution_time AS Last_Execution
    ,SUBSTRING(
        st.text
        ,(qs.statement_start_offset / 2) + 1
        ,((CASE 
            WHEN qs.statement_end_offset = -1 THEN DATALENGTH(st.text) 
            ELSE qs.statement_end_offset 
           END - qs.statement_start_offset) / 2) + 1
     ) AS Query_Text
    ,DB_NAME(st.dbid) AS DatabaseName
    ,OBJECT_NAME(st.objectid, st.dbid) AS ObjectName
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE execution_count > 0
    AND total_grant_kb > 0
ORDER BY Avg_Grant_MB_per_exec DESC;


PRINT '================================================================================';
PRINT 'CURRENTLY EXECUTING / WAITING QUERIES WITH MEMORY GRANTS';
PRINT '   (Real-time view - includes requested, granted, used memory)';
PRINT '   (High requested but low granted often means RESOURCE_SEMAPHORE waits)';
PRINT '================================================================================';

SELECT 
    mg.session_id AS SessionID
    ,mg.requested_memory_kb / 1024.0 AS Requested_MB
    ,mg.granted_memory_kb / 1024.0 AS Granted_MB
    ,mg.used_memory_kb / 1024.0 AS Used_MB
    ,mg.max_used_memory_kb / 1024.0 AS Max_Used_MB
    ,mg.wait_time_ms / 1000.0 AS Wait_Seconds
    ,mg.queue_id AS QueueID
    ,mg.wait_order AS WaitOrder
    ,r.wait_type AS Current_Wait_Type
    ,r.status AS Request_Status
    ,SUBSTRING(
        st.text
        ,(r.statement_start_offset / 2) + 1
        ,((CASE 
            WHEN r.statement_end_offset = -1 THEN DATALENGTH(st.text) 
            ELSE r.statement_end_offset 
           END - r.statement_start_offset) / 2) + 1
     ) AS Query_Text
    ,DB_NAME(r.database_id) AS DatabaseName
FROM sys.dm_exec_query_memory_grants mg
INNER JOIN sys.dm_exec_requests r 
    ON mg.session_id = r.session_id
    AND mg.request_id = r.request_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE mg.requested_memory_kb > 0
ORDER BY mg.requested_memory_kb DESC;


PRINT '================================================================================';
PRINT 'Top Queries by Memory Usage Complete';
PRINT 'High memory grants often indicate large sorts, hash joins, or missing indexes.';
PRINT 'Consider rewriting queries, adding covering indexes, or adjusting server memory settings.';
PRINT '================================================================================';