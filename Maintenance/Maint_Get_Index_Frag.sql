/*
    Index Fragmentation Detector
    =========================================================================
    Purpose:    Scans for fragmented indexes in a specified database or the 
                current context database. Recommends actions based on fragmentation levels:
                - >30% → REBUILD
                - 5-30% → REORGANIZE
                - <5% → OK (no action)
    Author:     Thomas Thomasson (Written with Grok)
    Compatible: SQL Server 2016+
    Usage:      EXEC usp_DetectIndexFragmentation @DatabaseName = 'YourDB';  -- or omit for current DB
                Results ordered by fragmentation descending.
    Notes:      - Uses sys.dm_db_index_physical_stats (LIMITED mode for speed)
                - Only scans indexes with >1000 pages (configurable)
                - Excludes heaps (index_id=0) and system tables
                - Run during maintenance windows; does NOT fix — just reports
    =========================================================================
*/

CREATE OR ALTER PROCEDURE usp_DetectIndexFragmentation
    @DatabaseName nvarchar(128) = NULL,     -- Optional: DB to scan; NULL = current DB
    @MinPageCount int = 1000,               -- Ignore small indexes (< this pages)
    @FragRebuildThreshold decimal(5,2) = 30.00, -- % for REBUILD recommendation
    @FragReorgThreshold decimal(5,2) = 5.00 -- % for REORGANIZE recommendation
AS
BEGIN
    SET NOCOUNT ON;

    -- Use current DB if not specified
    IF @DatabaseName IS NULL
        SET @DatabaseName = DB_NAME();

    -- Validate DB exists
    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @DatabaseName)
    BEGIN
        RAISERROR('Database ''%s'' does not exist.', 16, 1, @DatabaseName);
        RETURN;
    END

    PRINT '================================================================================';
    PRINT 'INDEX FRAGMENTATION REPORT FOR DATABASE: ' + @DatabaseName;
    PRINT '   (Scanned at: ' + CONVERT(varchar(20), GETDATE(), 120) + ')';
    PRINT '   Recommendations: REBUILD (> ' + CAST(@FragRebuildThreshold AS varchar(5)) + '%), REORGANIZE (' + CAST(@FragReorgThreshold AS varchar(5)) + '-' + CAST(@FragRebuildThreshold AS varchar(5)) + '%), OK (< ' + CAST(@FragReorgThreshold AS varchar(5)) + '%)';
    PRINT '================================================================================';

    -- Dynamic SQL to run in context of target DB
    DECLARE @Sql nvarchar(max) = N'
    USE ' + QUOTENAME(@DatabaseName) + N';
    SELECT
        DB_NAME() AS DatabaseName
        ,OBJECT_SCHEMA_NAME(ips.object_id) + ''.'' + OBJECT_NAME(ips.object_id) AS TableName
        ,i.name AS IndexName
        ,ips.index_type_desc AS IndexType
        ,ips.avg_fragmentation_in_percent AS AvgFragmentationPct
        ,ips.page_count AS PageCount
        ,ips.alloc_unit_type_desc AS AllocUnitType
        ,CASE 
            WHEN ips.avg_fragmentation_in_percent > ' + CAST(@FragRebuildThreshold AS nvarchar(10)) + N' THEN ''REBUILD''
            WHEN ips.avg_fragmentation_in_percent BETWEEN ' + CAST(@FragReorgThreshold AS nvarchar(10)) + N' AND ' + CAST(@FragRebuildThreshold AS nvarchar(10)) + N' THEN ''REORGANIZE''
            ELSE ''OK''
         END AS RecommendedAction
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, ''LIMITED'') ips
    INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE ips.index_id > 0                              -- exclude heaps
        AND ips.page_count > ' + CAST(@MinPageCount AS nvarchar(10)) + N'   -- ignore small indexes
        AND ips.alloc_unit_type_desc = ''IN_ROW_DATA''  -- focus on row data
    ORDER BY ips.avg_fragmentation_in_percent DESC;';

    EXEC sp_executesql @Sql;

    PRINT '================================================================================';
    PRINT 'Index Fragmentation Scan Complete';
    PRINT 'To fix: Use ALTER INDEX ... REBUILD/REORGANIZE or Ola Hallengren''s IndexOptimize.';
    PRINT '================================================================================';
END;
GO