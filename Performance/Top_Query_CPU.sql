/*
    Top Queries by CPU
    =========================================================================
    Purpose:    Identifies the most CPU-intensive queries from the plan cache
                Shows total CPU time, average CPU per execution, execution count,
                and the query text for quick analysis.
    Author:     Thomas Thomasson (written with Grok)
    Compatible: SQL Server 2016+
    Usage:      Run in SSMS / Azure Data Studio. Look at top rows for suspects.
                Clears cache only if you uncomment the DBCC line (use with caution!).
    Notes:      Data comes from sys.dm_exec_query_stats (plan cache).
                Results reset on server restart, plan eviction, or DBCC FREEPROCCACHE.
    =========================================================================
*/

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

-- Uncomment ONLY if you need to clear the plan cache for a fresh view (careful - impacts performance!)
-- DBCC FREEPROCCACHE WITH NO_INFOMSGS;

PRINT '================================================================================';
PRINT 'TOP QUERIES BY TOTAL CPU TIME (Cumulative since last cache clear/restart)';
PRINT '   (Most CPU-hungry overall - often frequent or expensive queries)';
PRINT '================================================================================';

SELECT TOP 20
    total_worker_time / 1000000.0 AS Total_CPU_Seconds
    ,total_worker_time / 1000.0 / execution_count AS Avg_CPU_ms_per_exec
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
WHERE total_worker_time > 0
ORDER BY total_worker_time DESC;


PRINT '================================================================================';
PRINT 'TOP QUERIES BY AVERAGE CPU PER EXECUTION (Most expensive individual runs)';
PRINT '   (High avg CPU but lower execution count - optimization candidates)';
PRINT '================================================================================';

SELECT TOP 20
    total_worker_time / 1000.0 / execution_count AS Avg_CPU_ms_per_exec
    ,total_worker_time / 1000000.0 AS Total_CPU_Seconds
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
    AND total_worker_time > 0
ORDER BY Avg_CPU_ms_per_exec DESC;


PRINT '================================================================================';
PRINT 'Top Queries by CPU Complete';
PRINT 'Review high Total_CPU or high Avg_CPU entries above.';
PRINT 'Consider adding indexes, rewriting queries, or parameter sniffing fixes.';
PRINT '================================================================================';