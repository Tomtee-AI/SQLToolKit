-- Queries with tempdb spills (sort / hash warnings)
SELECT TOP 20
    qt.query_sql_text,
    SUM(qrs.avg_tempdb_space_used * 8.0 / 1024 / 1024) AS TotalTempdbSpill_MB,
    AVG(qrs.avg_tempdb_space_used * 8.0 / 1024 / 1024) AS AvgSpill_MB,
    COUNT(*) AS ExecutionCount,
    p.plan_id
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats qrs ON p.plan_id = qrs.plan_id
JOIN sys.query_store_runtime_stats_interval rsi ON qrs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
WHERE qrs.avg_tempdb_space_used > 0
  AND rsi.start_time >= DATEADD(DAY, -30, GETDATE())
GROUP BY qt.query_sql_text, p.plan_id
ORDER BY TotalTempdbSpill_MB DESC;