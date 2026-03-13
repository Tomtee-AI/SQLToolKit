-- Queries where duration / CPU varies a lot (high standard deviation)
SELECT TOP 20
    qt.query_sql_text,
    COUNT(DISTINCT p.plan_id)                  AS PlanCount,
    AVG(qrs.avg_duration)                   AS AvgDurationMs,
    STDEV(qrs.avg_duration)                 AS StdDevDurationMs,
    MAX(qrs.avg_duration) - MIN(qrs.avg_duration) AS DurationRangeMs,
    SUM(qrs.count_executions)                  AS TotalExecutions
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats qrs ON p.plan_id = qrs.plan_id
JOIN sys.query_store_runtime_stats_interval rsi ON qrs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
WHERE rsi.start_time >= DATEADD(DAY, -30, GETDATE())
GROUP BY qt.query_sql_text
HAVING COUNT(DISTINCT p.plan_id) >= 2
   AND STDEV(qrs.avg_duration) > 500          -- adjust threshold
ORDER BY StdDevDurationMs DESC;