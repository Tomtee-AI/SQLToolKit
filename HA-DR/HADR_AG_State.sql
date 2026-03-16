-- AG Database Replication Status Overview
SELECT 
    ag.name AS AGName,
    adc.database_name AS DatabaseName,
    drs.replica_id AS ReplicaID,
    ar.replica_server_name AS ReplicaServer,
    drs.synchronization_state_desc AS SyncState,  -- HEALTHY, PARTIALLY_HEALTHY, UNHEALTHY
    drs.synchronization_health_desc AS SyncHealth,
    CASE WHEN ar.availability_mode_desc = 'SYNCHRONOUS_COMMIT' THEN 'Yes' ELSE 'No' END AS IsSynchronous,
    drs.is_primary_replica AS IsPrimaryReplica,
    drs.redo_queue_size / 1024.0 AS RedoQueue_MB,  -- Pending redo on secondary (high = bottleneck)
    drs.log_send_queue_size / 1024.0 AS LogSendQueue_MB,  -- Pending log send to secondary
    drs.last_redone_time AS LastRedoneTime,
    drs.last_commit_time AS LastCommitTime,
    drcs.is_failover_ready AS FailoverReady  -- 1 = ready for failover
FROM sys.availability_groups ag
JOIN sys.availability_databases_cluster adc ON ag.group_id = adc.group_id
JOIN sys.dm_hadr_database_replica_cluster_states drcs ON drcs.group_database_id = adc.group_database_id
JOIN sys.dm_hadr_database_replica_states drs ON adc.group_database_id = drs.group_database_id
JOIN sys.availability_replicas ar ON drs.replica_id = ar.replica_id
ORDER BY ag.name, adc.database_name, ar.replica_server_name;