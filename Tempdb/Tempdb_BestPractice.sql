/*
    TempDB Configuration Health Check
    =========================================================================
    Purpose:    Evaluates current tempdb setup against Microsoft best practices
                (2022–2026 guidance) and flags deviations.
    Author:     Thomas Thomasson (Written with Grok)
    Compatible: SQL Server 2016+
    Usage:      Execute in any database context (uses tempdb directly).
    Recommendations checked:
      - Number of data files (general rule: 1 per logical CPU up to 8, then +4 per 8 CPUs)
      - Equal initial size & growth settings across files
      - File growth in MB (not %)
      - Trace flags 1117 / 1118 (mostly obsolete in modern versions)
      - Multiple files on separate drives (physical or logical)
    Notes:      Some rules are guidelines — not strict requirements.
                Always test changes in non-prod first.
    =========================================================================
*/


SET NOCOUNT ON;

-- ────────────────────────────────────────────────
-- Variables & table for tempdb file info
-- ────────────────────────────────────────────────
DECLARE 
    @CpuCount           int             = NULL,
    @RecommendedFiles   int             = NULL,
    @FileCount          int             = NULL,
    @MaxSizeMB          decimal(18,2)  = NULL,
    @MaxGrowthMB        decimal(18,2)  = NULL,
    @EqualSize          bit             = 1,
    @EqualGrowth        bit             = 1,
    @GrowthInMB         bit             = 1,
    @OnMultipleDrives   bit             = 0,
    @Msg                nvarchar(4000)  = NULL;

DECLARE @FileInfo TABLE (
    LogicalName         sysname         NULL,
    PhysicalPath        nvarchar(max)   NULL,
    FileType            nvarchar(60)    NULL,
    SizeMB              decimal(18,2)   NULL,
    MaxSizeMB           decimal(18,2)   NULL,
    GrowthMB            decimal(18,2)   NULL,
    GrowthIsPercent     bit             NULL,
    DriveLetterOrFolder nvarchar(512)   NULL
);

-- Get logical CPU count
SELECT @CpuCount = cpu_count FROM sys.dm_os_sys_info;

-- Calculate recommended file count
SET @RecommendedFiles = 
    CASE 
        WHEN @CpuCount <= 8 THEN @CpuCount
        ELSE 8 + ((@CpuCount - 8) / 8) * 4
    END;

-- Populate tempdb file information (explicit cast to avoid sql_variant issues)
INSERT INTO @FileInfo
SELECT 
    name,
    CAST(physical_name AS nvarchar(max)),
    type_desc,
    size * 8.0 / 1024,
    max_size * 8.0 / 1024,
    growth * 8.0 / 1024,
    CASE WHEN growth < 0 THEN 1 ELSE 0 END,
    LEFT(CAST(physical_name AS nvarchar(max)), 
         CHARINDEX('\', REVERSE(CAST(physical_name AS nvarchar(max)))) - 1)
FROM tempdb.sys.database_files;

-- Compute max values for size & growth (data files only)
SELECT 
    @MaxSizeMB   = MAX(SizeMB),
    @MaxGrowthMB = MAX(GrowthMB)
FROM @FileInfo
WHERE FileType = 'ROWS';

-- Calculate aggregates & flags
SELECT 
    @FileCount      = COUNT(*),
    @EqualSize      = CASE WHEN COUNT(*) = SUM(CASE WHEN SizeMB   = @MaxSizeMB   THEN 1 ELSE 0 END) THEN 1 ELSE 0 END,
    @EqualGrowth    = CASE WHEN COUNT(*) = SUM(CASE WHEN GrowthMB = @MaxGrowthMB THEN 1 ELSE 0 END) THEN 1 ELSE 0 END,
    @GrowthInMB     = MIN(CASE WHEN GrowthIsPercent = 0 THEN 1 ELSE 0 END)
FROM @FileInfo
WHERE FileType = 'ROWS';

-- Check multiple drives/folders
SELECT @OnMultipleDrives = 
    CASE WHEN COUNT(DISTINCT DriveLetterOrFolder) > 1 THEN 1 ELSE 0 END
FROM @FileInfo
WHERE FileType = 'ROWS';

-- ────────────────────────────────────────────────
-- Output
-- ────────────────────────────────────────────────

PRINT '================================================================================';
PRINT 'TEMPDB CONFIGURATION HEALTH CHECK';
PRINT '   Server          : ' + @@SERVERNAME;
PRINT '   Logical CPUs    : ' + ISNULL(CAST(@CpuCount AS varchar(10)), 'Unknown');
PRINT '   Recommended data files : ' + ISNULL(CAST(@RecommendedFiles AS varchar(10)), 'Unknown');
PRINT '   Current data files     : ' + ISNULL(CAST(@FileCount AS varchar(10)), 'Unknown');
PRINT '   Scanned at      : ' + CONVERT(varchar(20), GETDATE(), 120);
PRINT '================================================================================';

-- Summary table
SELECT 
    CASE 
        WHEN @FileCount >= @RecommendedFiles THEN 'PASS'
        WHEN @FileCount >= 4 AND @CpuCount > 8 THEN 'ACCEPTABLE (conservative)'
        ELSE 'WARNING - Too few files'
    END AS FileCountStatus,
    @FileCount AS ActualFiles,
    @RecommendedFiles AS RecommendedMin,
    CASE WHEN @EqualSize = 1 THEN 'Yes' ELSE 'No - unequal sizes' END AS EqualInitialSize,
    CASE 
        WHEN @GrowthInMB = 0   THEN 'No - growth in %'
        WHEN @EqualGrowth = 0  THEN 'No - unequal growth amounts'
        ELSE 'Yes'
    END AS EqualGrowthInMB,
    CASE WHEN @OnMultipleDrives = 1 THEN 'Yes (multiple locations)' 
         ELSE 'No (single location)' 
    END AS FilesOnMultipleDrives;

PRINT '';
PRINT 'Detailed Recommendations & Status:';
PRINT '───────────────────────────────────────';

-- 1. File count
SET @Msg = 'File count check: ';
IF @FileCount < @RecommendedFiles
    SET @Msg += 'WARNING - Consider adding files up to ~' + CAST(@RecommendedFiles AS varchar(10)) + ' (1 per CPU up to 8, then +4 per additional 8 CPUs)';
ELSE IF @FileCount > @RecommendedFiles * 2
    SET @Msg += 'INFO - More files than typical recommendation (may be intentional)';
ELSE
    SET @Msg += 'GOOD - Meets or exceeds general guideline';
PRINT @Msg;

-- 2. Equal initial size
SET @Msg = 'All data files have equal initial size: ';
SET @Msg += CASE WHEN @EqualSize = 1 THEN 'YES' ELSE 'NO - different starting sizes detected' END;
PRINT @Msg;

-- 3. Growth settings
SET @Msg = 'Growth is fixed MB and equal across all data files: ';
SET @Msg += CASE 
    WHEN @GrowthInMB = 0   THEN 'NO - some/all files grow in %'
    WHEN @EqualGrowth = 0  THEN 'NO - different growth increments'
    ELSE 'YES'
END;
PRINT @Msg;

-- 4. Multiple locations
SET @Msg = 'Files are spread across multiple drives/folders: ';
SET @Msg += CASE WHEN @OnMultipleDrives = 1 THEN 'YES (good for I/O)' 
                 ELSE 'NO - all files in same location (potential bottleneck)'
            END;
PRINT @Msg;

-- 5. Obsolete trace flags
IF EXISTS (
    SELECT 1 
    FROM sys.dm_server_registry 
    WHERE registry_key LIKE '%SuperSocketNetLib%' 
      AND (
          value_name LIKE '%TraceFlag%' 
          OR CAST(value_data AS nvarchar(max)) LIKE '%-T1117%' 
          OR CAST(value_data AS nvarchar(max)) LIKE '%-T1118%'
      )
)
    PRINT 'Trace flags 1117/1118 detected → mostly obsolete since SQL 2016+ (autogrow all files & uniform extents are default behavior)';
ELSE
    PRINT 'No obsolete trace flags 1117/1118 detected (good)';

PRINT '';
PRINT 'Quick Action Summary:';
IF @FileCount < @RecommendedFiles OR @EqualSize = 0 OR @GrowthInMB = 0 OR @EqualGrowth = 0 OR @OnMultipleDrives = 0
    PRINT '→ Action recommended: Review and align tempdb configuration to best practices.';
ELSE
    PRINT '→ Current configuration appears solid according to general Microsoft guidelines.';

PRINT '================================================================================';
PRINT 'End of TempDB Configuration Check';
PRINT 'Note: Always test changes (adding files, resizing, etc.) in non-production first.';
PRINT '================================================================================';