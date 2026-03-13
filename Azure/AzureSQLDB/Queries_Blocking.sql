SELECT 
    r.session_id AS BlockedSession,
    r.blocking_session_id AS Blocker,
    r.wait_type,
    r.wait_time / 1000.0 AS WaitSec,
    SUBSTRING(t.text, r.statement_start_offset/2 + 1, 
              ((CASE WHEN r.statement_end_offset = -1 
                     THEN LEN(CONVERT(nvarchar(max), t.text)) * 2 
                     ELSE r.statement_end_offset END - r.statement_start_offset)/2) + 1) AS BlockedQuery,
    SUBSTRING(bt.text, br.statement_start_offset/2 + 1, 
              ((CASE WHEN br.statement_end_offset = -1 
                     THEN LEN(CONVERT(nvarchar(max), bt.text)) * 2 
                     ELSE br.statement_end_offset END - br.statement_start_offset)/2) + 1) AS BlockerQuery
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_requests br ON r.blocking_session_id = br.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
CROSS APPLY sys.dm_exec_sql_text(br.sql_handle) bt
WHERE r.blocking_session_id <> 0
  AND r.database_id = DB_ID()
ORDER BY r.wait_time DESC;