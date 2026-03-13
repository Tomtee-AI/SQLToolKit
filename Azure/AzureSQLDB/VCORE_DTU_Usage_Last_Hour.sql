SELECT TOP 60
    ,end_time
    ,avg_cpu_percent
    ,avg_data_io_percent
    ,avg_log_write_percent
    ,avg_memory_usage_percent
    ,xtp_storage_percent      -- In-Memory OLTP if used
    ,max_worker_percent
    ,max_session_percent
FROM sys.dm_db_resource_stats
ORDER BY end_time DESC;