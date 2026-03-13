WITH RecentStats AS (
    SELECT 
        q.query_id,
        p.plan_id,
        AVG(qrs.avg_duration) AS AvgDurationMs,
        ROW_NUMBER() OVER (PARTITION BY q.query_id ORDER BY MIN(rsi.start_time) ASC) AS rn_old,
        ROW_NUMBER() OVER (PARTITION BY q.query_id ORDER BY MIN(rsi.start_time) DESC) AS rn_new
    FROM sys.query_store_query q
    JOIN sys.query_store_plan p ON q.query_id = p.query_id
    JOIN sys.query_store_runtime_stats qrs ON p.plan_id = qrs.plan_id
    JOIN sys.query_store_runtime_stats_interval rsi ON qrs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
    WHERE rsi.start_time >= DATEADD(DAY, -30, GETDATE())
    GROUP BY q.query_id, p.plan_id
)
SELECT TOP 20
    qt.query_sql_text,
    new.AvgDurationMs AS NewAvgDurationMs,
    old.AvgDurationMs AS OldAvgDurationMs,
    new.AvgDurationMs / NULLIF(old.AvgDurationMs, 0) AS DurationRatio,
    new.plan_id AS NewPlanID,
    old.plan_id AS OldPlanID
FROM RecentStats new
JOIN RecentStats old ON new.query_id = old.query_id AND new.rn_new = 1 AND old.rn_old = 1
JOIN sys.query_store_query_text qt ON (SELECT query_text_id FROM sys.query_store_query WHERE query_id = new.query_id) = qt.query_text_id
WHERE new.AvgDurationMs > old.AvgDurationMs * 2
ORDER BY DurationRatio DESC;