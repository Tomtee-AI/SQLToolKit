SELECT TOP 20
    dm_mid.equality_columns,
    dm_mid.inequality_columns,
    dm_mid.included_columns,
    dm_mid.statement AS TableName,
    dm_migs.avg_user_impact * (dm_migs.user_seeks + dm_migs.user_scans) AS ImpactScore,
    dm_migs.user_seeks + dm_migs.user_scans AS TotalSeeksScans
FROM sys.dm_db_missing_index_groups dm_mig
JOIN sys.dm_db_missing_index_group_stats dm_migs ON dm_mig.index_group_handle = dm_migs.group_handle
JOIN sys.dm_db_missing_index_details dm_mid ON dm_mig.index_handle = dm_mid.index_handle
ORDER BY ImpactScore DESC;