WITH Stats AS (
    SELECT q.query_id, p.plan_id, AVG(rs.avg_duration / 1000.0) AS AvgDurationSec,
           ROW_NUMBER() OVER (PARTITION BY q.query_id ORDER BY MIN(rsi.start_time) ASC) AS rn_old,
           ROW_NUMBER() OVER (PARTITION BY q.query_id ORDER BY MIN(rsi.start_time) DESC) AS rn_new
    FROM sys.query_store_query q
    JOIN sys.query_store_plan p ON q.query_id = p.query_id
    JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
    JOIN sys.query_store_runtime_stats_interval rsi ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
    WHERE rsi.start_time >= DATEADD(DAY, -30, GETUTCDATE())
    GROUP BY q.query_id, p.plan_id
)
SELECT TOP 20 qt.query_sql_text AS QueryText,
       new.AvgDurationSec AS NewAvgDurationSec,
       old.AvgDurationSec AS OldAvgDurationSec,
       new.AvgDurationSec / NULLIF(old.AvgDurationSec, 0) AS DurationRatio,
       new.plan_id AS NewPlanID,
       old.plan_id AS OldPlanID
FROM Stats new
JOIN Stats old ON new.query_id = old.query_id AND new.rn_new = 1 AND old.rn_old = 1
JOIN sys.query_store_query_text qt ON (SELECT query_text_id FROM sys.query_store_query WHERE query_id = new.query_id) = qt.query_text_id
WHERE new.AvgDurationSec > old.AvgDurationSec * 2  -- 2x worse threshold
ORDER BY DurationRatio DESC;