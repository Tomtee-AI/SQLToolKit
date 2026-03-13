-- Worst queries in the last hour
SELECT TOP 20
    qt.query_sql_text,
    SUM(qrs.count_executions) AS Executions,
    SUM(qrs.avg_cpu_time * qrs.count_executions) / 1000.0 AS TotalCPUSec,
    MAX(qrs.max_duration) AS MaxDurationMs,
    p.plan_id
FROM sys.query_store_plan p
JOIN sys.query_store_query q ON p.query_id = q.query_id
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_runtime_stats qrs ON p.plan_id = qrs.plan_id
JOIN sys.query_store_runtime_stats_interval rsi ON qrs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
WHERE rsi.start_time >= DATEADD(HOUR, -1, GETDATE())
GROUP BY qt.query_sql_text, p.plan_id
ORDER BY TotalCPUSec DESC;