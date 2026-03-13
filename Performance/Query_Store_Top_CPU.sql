-- Top 20 queries by total CPU time (last 30 days)
SELECT TOP 20
    qt.query_sql_text                          AS QueryText,
    SUM(qrs.count_executions)                  AS ExecutionCount,
    SUM(qrs.avg_cpu_time * qrs.count_executions) / 1000.0 AS TotalCPUSec,
    AVG(qrs.avg_cpu_time)                   AS AvgCPUMs,
    SUM(qrs.avg_duration * qrs.count_executions) / 1000.0 AS TotalDurationSec,
    AVG(qrs.avg_duration)                   AS AvgDurationMs,
    SUM(qrs.avg_logical_io_reads * qrs.count_executions) AS TotalLogicalReads,
    q.query_id,
    p.plan_id
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats qrs ON p.plan_id = qrs.plan_id
JOIN sys.query_store_runtime_stats_interval rsi ON qrs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
WHERE rsi.start_time >= DATEADD(DAY, -30, GETDATE())
GROUP BY qt.query_sql_text, q.query_id, p.plan_id
ORDER BY TotalCPUSec DESC;