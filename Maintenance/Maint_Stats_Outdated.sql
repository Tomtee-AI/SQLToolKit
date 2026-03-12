/*
    Outdated Statistics Detector
    =========================================================================
    Purpose:    Scans for outdated statistics in a specified database or the 
                current context database. Recommends UPDATE STATISTICS if 
                modification_counter > threshold % of rows (default 20%).
    Author:     Thomas Thomasson (Written with Grok)
    Compatible: SQL Server 2016+
    Usage:      EXEC usp_DetectOutdatedStatistics @DatabaseName = 'YourDB';  -- or omit for current DB
                Results ordered by % modified descending.
    Notes:      - Uses sys.dm_db_stats_properties for stats details
                - Scans all user tables; excludes system tables
                - Only checks stats with rows > 0
                - Run during maintenance windows; does NOT update — just reports
    =========================================================================
*/

CREATE OR ALTER PROCEDURE usp_DetectOutdatedStatistics
    @DatabaseName nvarchar(128) = NULL,
    @ModThresholdPct decimal(5,2) = 20.00
AS
BEGIN
    SET NOCOUNT ON;

    IF @DatabaseName IS NULL
        SET @DatabaseName = DB_NAME();

    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @DatabaseName)
    BEGIN
        RAISERROR('Database ''%s'' does not exist.', 16, 1, @DatabaseName);
        RETURN;
    END

    PRINT '================================================================================';
    PRINT 'OUTDATED STATISTICS REPORT FOR DATABASE: ' + @DatabaseName;
    PRINT '   (Scanned at: ' + CONVERT(varchar(20), GETDATE(), 120) + ')';
    PRINT '   Recommendation: UPDATE STATISTICS if modified > ' + CAST(@ModThresholdPct AS varchar(5)) + '% of rows';
    PRINT '================================================================================';

    DECLARE @Sql nvarchar(max) = N'
    USE ' + QUOTENAME(@DatabaseName) + N';
    SELECT
        DB_NAME() AS DatabaseName
        ,OBJECT_SCHEMA_NAME(s.object_id) + ''.'' + OBJECT_NAME(s.object_id) AS TableName
        ,s.name AS StatsName
        ,sp.last_updated AS LastUpdated
        ,sp.rows AS Rows
        ,sp.rows_sampled AS RowsSampled
        ,sp.modification_counter AS ModificationCounter
        ,CAST( 
            (sp.modification_counter * 100.0) / NULLIF(sp.rows, 0) 
            AS decimal(12,4)
         ) AS PctModified
        ,CASE 
            WHEN (sp.modification_counter * 100.0) / NULLIF(sp.rows, 0) > ' + CAST(@ModThresholdPct AS nvarchar(10)) + N' 
                 THEN ''UPDATE STATISTICS''
            ELSE ''OK''
         END AS RecommendedAction
    FROM sys.stats s
    CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
    WHERE OBJECTPROPERTY(s.object_id, ''IsUserTable'') = 1
        AND sp.rows > 0
    ORDER BY PctModified DESC;';

    EXEC sp_executesql @Sql;

    PRINT '================================================================================';
    PRINT 'Outdated Statistics Scan Complete';
    PRINT 'To fix: Use UPDATE STATISTICS ... or Ola Hallengren''s IndexOptimize.';
    PRINT '================================================================================';
END;
GO