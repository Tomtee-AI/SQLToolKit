/*
    TempDB Consumers - Top Sessions & Queries
    =========================================================================
    Purpose:    Identifies sessions and queries currently consuming the most
                space in tempdb (user objects like #temp tables, spills, sorts,
                hashes, version store, etc.).
    Author:     Thomas Thomasson (written with Grok)
    Compatible: SQL Server 2016+
    Usage:      Run in SSMS / Azure Data Studio when tempdb is growing fast.
                Requires VIEW SERVER STATE permission.
    Notes:      - Values are in pages (8 KB each) ? multiply by 8 for KB
                - Net allocation = alloc - dealloc (outstanding usage)
                - Data is real-time (snapshot); does NOT persist history
                - High internal usage often = query spills (add memory/indexes)
    =========================================================================
*/

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

PRINT '================================================================================';
PRINT '1. TEMPD B OVERALL SPACE USAGE BREAKDOWN';
PRINT '   (Pages × 8 = KB; look for high user/internal/version store usage)';
PRINT '================================================================================';

SELECT
    (SUM(user_object_reserved_page_count) * 8.0 / 1024) AS User_Objects_MB
    ,(SUM(internal_object_reserved_page_count) * 8.0 / 1024) AS Internal_Objects_MB
    ,(SUM(version_store_reserved_page_count) * 8.0 / 1024) AS Version_Store_MB
    ,(SUM(unallocated_extent_page_count) * 8.0 / 1024) AS Free_Space_MB
    ,(SUM(user_object_reserved_page_count + internal_object_reserved_page_count + version_store_reserved_page_count + unallocated_extent_page_count) * 8.0 / 1024) AS Total_Used_MB
FROM tempdb.sys.dm_db_file_space_usage;


PRINT '================================================================================';
PRINT '2. TOP SESSIONS BY NET TEMPD B SPACE USAGE (sys.dm_db_session_space_usage)';
PRINT '   (Net = allocated - deallocated; high values = long-lived temp objects)';
PRINT '================================================================================';

SELECT TOP 20
    s.session_id AS SessionID
    ,s.login_name AS LoginName
    ,s.program_name AS ProgramName
    ,s.host_name AS HostName
    ,(su.user_objects_alloc_page_count - su.user_objects_dealloc_page_count) * 8.0 / 1024 AS User_Objects_Net_MB
    ,(su.internal_objects_alloc_page_count - su.internal_objects_dealloc_page_count) * 8.0 / 1024 AS Internal_Objects_Net_MB
    ,(su.user_objects_alloc_page_count + su.internal_objects_alloc_page_count - su.user_objects_dealloc_page_count - su.internal_objects_dealloc_page_count) * 8.0 / 1024 AS Total_Net_MB
FROM sys.dm_db_session_space_usage su
INNER JOIN sys.dm_exec_sessions s ON su.session_id = s.session_id
WHERE s.session_id > 50                             -- exclude system sessions
    AND (su.user_objects_alloc_page_count + su.internal_objects_alloc_page_count) > 0
ORDER BY (su.user_objects_alloc_page_count + su.internal_objects_alloc_page_count - su.user_objects_dealloc_page_count - su.internal_objects_dealloc_page_count) DESC;


PRINT '================================================================================';
PRINT '3. TOP ACTIVE REQUESTS / TASKS BY OUTSTANDING TEMPD B ALLOCATIONS';
PRINT '   (Current spills, sorts, hashes, temp tables in active queries)';
PRINT '================================================================================';

SELECT TOP 20
    tsu.session_id AS SessionID
    ,tsu.request_id AS RequestID
    ,r.status AS RequestStatus
    ,r.wait_type AS CurrentWait
    ,(tsu.user_objects_alloc_page_count - tsu.user_objects_dealloc_page_count) * 8.0 / 1024 AS User_Objects_Outstanding_MB
    ,(tsu.internal_objects_alloc_page_count - tsu.internal_objects_dealloc_page_count) * 8.0 / 1024 AS Internal_Objects_Outstanding_MB
    ,((tsu.user_objects_alloc_page_count - tsu.user_objects_dealloc_page_count) + 
      (tsu.internal_objects_alloc_page_count - tsu.internal_objects_dealloc_page_count)) * 8.0 / 1024 AS Total_Outstanding_MB
    ,SUBSTRING(
        st.text
        ,(r.statement_start_offset / 2) + 1
        ,((CASE 
            WHEN r.statement_end_offset = -1 THEN DATALENGTH(st.text) 
            ELSE r.statement_end_offset 
           END - r.statement_start_offset) / 2) + 1
     ) AS Query_Text
    ,DB_NAME(r.database_id) AS DatabaseName
FROM sys.dm_db_task_space_usage tsu
INNER JOIN sys.dm_exec_requests r ON tsu.session_id = r.session_id AND tsu.request_id = r.request_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE (tsu.user_objects_alloc_page_count + tsu.internal_objects_alloc_page_count) > 0
ORDER BY (tsu.user_objects_alloc_page_count + tsu.internal_objects_alloc_page_count - tsu.user_objects_dealloc_page_count - tsu.internal_objects_dealloc_page_count) DESC;


PRINT '================================================================================';
PRINT 'TempDB Consumers Report Complete';
PRINT 'High user_objects ? temp tables / table variables not dropped';
PRINT 'High internal_objects ? query spills (sort/hash) due to low memory or bad estimates';
PRINT 'Consider: more RAM, better indexes, trace flag 1117/1118, multiple tempdb files.';
PRINT '================================================================================';