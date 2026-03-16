-- Enable Always On on the instance (run on Node1 and Node2)
ALTER DATABASE CURRENT SET HADR AVAILABILITY GROUP = OFF;  -- Safety if needed
GO

-- Check if enabled
SELECT SERVERPROPERTY('IsHadrEnabled') AS IsHadrEnabled;

-- Enable if not (requires restart)
IF SERVERPROPERTY('IsHadrEnabled') = 0
BEGIN
    PRINT 'Enabling Always On - Restart SQL Service after running!';
    EXEC sp_configure 'show advanced options', 1;
    RECONFIGURE;
    EXEC sp_configure 'hadr', 1;
    RECONFIGURE;
END
GO