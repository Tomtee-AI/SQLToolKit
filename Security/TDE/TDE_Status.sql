SELECT 
    db_name(database_id) AS DatabaseName,
    encryption_state_desc AS EncryptionState,  -- 3 = Encrypted, 2 = In Progress
    percent_complete AS PercentComplete,      -- 0-100% during encryption/decryption
    encryption_thumbprint AS Thumbprint
FROM sys.dm_database_encryption_keys
WHERE db_name(database_id) = 'YourDatabase';  -- Or remove filter for all DBs
