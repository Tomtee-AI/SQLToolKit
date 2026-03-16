-- Create the AG on primary
CREATE AVAILABILITY GROUP MyAG
WITH (DTC_SUPPORT = PER_DB)  -- Or NONE if no DTC needed
FOR DATABASE [TestDB1], [TestDB2]  -- Add DBs here or later
REPLICA ON 
    N'Node1' WITH (
        ENDPOINT_URL = N'TCP://Node1.yourdomain.com:5022',  -- Adjust FQDN/port
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,             -- Or ASYNCHRONOUS
        FAILOVER_MODE = AUTOMATIC,                          -- Or MANUAL
        BACKUP_PRIORITY = 50,                               -- Adjust as needed
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL),           -- READ_ONLY for readable secondary
        PRIMARY_ROLE (ALLOW_CONNECTIONS = ALL)              -- ALL for primary
    ),
    N'Node2' WITH (
        ENDPOINT_URL = N'TCP://Node2.yourdomain.com:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        FAILOVER_MODE = AUTOMATIC,
        BACKUP_PRIORITY = 10,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL),
        PRIMARY_ROLE (ALLOW_CONNECTIONS = ALL)
    );
GO