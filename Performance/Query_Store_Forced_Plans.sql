-- All queries that have a forced plan
SELECT 
    qt.query_sql_text,
    p.plan_id,
    p.is_forced_plan,
    p.last_force_failure_reason_desc,
    COUNT(*) AS ExecutionCountLast30d
FROM sys.query_store_plan p
JOIN sys.query_store_query q ON p.query_id = q.query_id
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_runtime_stats qrs ON p.plan_id = qrs.plan_id
JOIN sys.query_store_runtime_stats_interval rsi ON qrs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
WHERE p.is_forced_plan = 1
  AND rsi.start_time >= DATEADD(DAY, -30, GETDATE())
GROUP BY qt.query_sql_text, p.plan_id, p.is_forced_plan, p.last_force_failure_reason_desc
ORDER BY ExecutionCountLast30d DESC;