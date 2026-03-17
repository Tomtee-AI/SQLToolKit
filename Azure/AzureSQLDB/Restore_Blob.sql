--Full
USE master;
GO

RESTORE DATABASE YourDatabaseName
FROM URL = 'https://mystorageaccount.blob.core.windows.net/mycontainer/YourDatabaseName_Full_20250317.bak'
WITH CREDENTIAL = 'https://mystorageaccount.blob.core.windows.net/',
     REPLACE,                    -- Overwrite existing database if it exists
     STATS = 10,
     RECOVERY;                   -- Bring database online (use NORECOVERY if you want to apply logs next)
GO

--Point In Time
USE master;
GO

-- Step 1: Restore Full Backup (with NORECOVERY)
RESTORE DATABASE YourDatabaseName
FROM URL = 'https://mystorageaccount.blob.core.windows.net/mycontainer/YourDatabaseName_Full_20250317.bak'
WITH CREDENTIAL = 'https://mystorageaccount.blob.core.windows.net/',
     REPLACE,
     NORECOVERY,
     STATS = 10;
GO

-- Step 2: Restore Latest Differential (with NORECOVERY)
RESTORE DATABASE YourDatabaseName
FROM URL = 'https://mystorageaccount.blob.core.windows.net/mycontainer/YourDatabaseName_Diff_20250317.bak'
WITH CREDENTIAL = 'https://mystorageaccount.blob.core.windows.net/',
     NORECOVERY,
     STATS = 10;
GO

-- Step 3: Restore Transaction Log(s) and bring online
RESTORE LOG YourDatabaseName
FROM URL = 'https://mystorageaccount.blob.core.windows.net/mycontainer/YourDatabaseName_Log_20250317.trn'
WITH CREDENTIAL = 'https://mystorageaccount.blob.core.windows.net/',
     RECOVERY,
     STATS = 10;
GO
