SELECT TOP 20
    r.session_id,
    r.start_time,
    r.status,
    r.total_elapsed_time / 1000.0 AS DurationSec,
    r.cpu_time AS CPUMs,
    r.logical_reads AS LogicalReads,
    r.writes AS Writes,
    SUBSTRING(t.text, r.statement_start_offset/2 + 1, 
              ((CASE WHEN r.statement_end_offset = -1 
                     THEN LEN(CONVERT(nvarchar(max), t.text)) * 2 
                     ELSE r.statement_end_offset END - r.statement_start_offset)/2) + 1) AS QueryText
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.database_id = DB_ID()
  AND r.session_id <> @@SPID  -- Exclude current session
ORDER BY r.total_elapsed_time DESC;