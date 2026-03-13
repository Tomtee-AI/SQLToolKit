SELECT TOP 20
    wait_type,
    wait_time_ms / 1000.0 AS WaitSec,
    waiting_tasks_count,
    max_wait_time_ms / 1000.0 AS MaxWaitSec,
    signal_wait_time_ms / 1000.0 AS SignalWaitSec
FROM sys.dm_os_wait_stats
WHERE wait_time_ms > 0
  AND wait_type NOT IN ('CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE', 'SLEEP_TASK', 'WAITFOR')  -- Exclude benign waits
ORDER BY wait_time_ms DESC;