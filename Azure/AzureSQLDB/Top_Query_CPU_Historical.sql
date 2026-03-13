SELECT TOP 20
    qt.query_sql_text AS QueryText,
    SUM(rs.count_executions) AS Executions,
    SUM(rs.avg_cpu_time / 1000.0) * SUM(rs.count_executions) AS TotalCPUSec,
    AVG(rs.avg_cpu_time / 1000.0) AS AvgCPUMs,
    AVG(rs.avg_duration / 1000.0) AS AvgDurationSec,
    q.query_id,
    p.plan_id
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
JOIN sys.query_store_runtime_stats_interval rsi ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
WHERE rsi.start_time >= DATEADD(DAY, -7, GETUTCDATE())
GROUP BY qt.query_sql_text, q.query_id, p.plan_id
ORDER BY TotalCPUSec DESC;