/*
    Security Overview: Logins → Users → Database Roles
    =========================================================================
    Purpose:    Shows server logins, their corresponding database users (across all DBs),
                user types, and the database roles each user belongs to.
    Author:     Thomas Thomasson (Written with Grok)
    Compatible: SQL Server 2012+
    Usage:      Execute in master or any database — results are cross-database.
    Notes:      - Excludes system users/logins (e.g. ##MS_PolicyTsqlExecutionLogin##)
                - Shows 'No database user' when a login has no user in a database
                - Sorted by login name, then database, then user/role
    =========================================================================
*/

SET NOCOUNT ON;

-- Temporary table to collect results from all databases
IF OBJECT_ID('tempdb..#UserRoles') IS NOT NULL DROP TABLE #UserRoles;

CREATE TABLE #UserRoles (
    ServerLogin     nvarchar(128)   NULL,
    LoginType       nvarchar(60)    NULL,
    LoginStatus     varchar(10)     NULL,
    DatabaseName    nvarchar(128)   NULL,
    UserName        nvarchar(128)   NULL,
    UserType        nvarchar(60)    NULL,
    DatabaseRoles   nvarchar(max)   NULL,
    DefaultSchema   nvarchar(128)   NULL,
    UserCreated     datetime        NULL
);

DECLARE @sql nvarchar(max) = N'';

-- Build dynamic SQL to run in each user database
SELECT @sql += 
    N'
    USE ' + QUOTENAME(name) + N';
    INSERT INTO #UserRoles (ServerLogin, LoginType, LoginStatus, DatabaseName, UserName, UserType, DatabaseRoles, DefaultSchema, UserCreated)
    SELECT 
        COALESCE(l.name, ''ORPHANED / NO LOGIN / Contained'') AS ServerLogin,
        l.type_desc AS LoginType,
        CASE WHEN l.is_disabled = 1 THEN ''DISABLED'' ELSE ''ENABLED'' END AS LoginStatus,
        DB_NAME() AS DatabaseName,
        dp.name AS UserName,
        dp.type_desc AS UserType,
        STRING_AGG(r.name, '', '') WITHIN GROUP (ORDER BY r.name) AS DatabaseRoles,
        dp.default_schema_name AS DefaultSchema,
        dp.create_date AS UserCreated
    FROM sys.database_principals dp
    LEFT JOIN sys.server_principals l 
        ON dp.sid = l.sid
    OUTER APPLY (
        SELECT r.name
        FROM sys.database_role_members drm
        INNER JOIN sys.database_principals r 
            ON drm.role_principal_id = r.principal_id
        WHERE drm.member_principal_id = dp.principal_id
    ) r
    WHERE dp.type IN (''S'',''U'',''G'',''C'',''K'')          -- SQL/Windows/Cert/Key users
      AND dp.name NOT IN (''dbo'',''guest'',''INFORMATION_SCHEMA'',''sys'')
      AND dp.name NOT LIKE ''##%''
    GROUP BY 
        l.name, l.type_desc, l.is_disabled, 
        dp.name, dp.type_desc, dp.default_schema_name, dp.create_date;
    '
FROM sys.databases
WHERE database_id > 4                               -- skip master, model, msdb, tempdb
  AND state_desc = 'ONLINE'
  AND is_read_only = 0;

-- Execute the generated SQL
EXEC sp_executesql @sql;

-- Add logins that have NO user in ANY database
INSERT INTO #UserRoles (ServerLogin, LoginType, LoginStatus, DatabaseName, UserName, UserType, DatabaseRoles, DefaultSchema, UserCreated)
SELECT 
    sp.name AS ServerLogin,
    sp.type_desc AS LoginType,
    CASE WHEN sp.is_disabled = 1 THEN 'DISABLED' ELSE 'ENABLED' END AS LoginStatus,
    'No database user found' AS DatabaseName,
    NULL AS UserName,
    NULL AS UserType,
    NULL AS DatabaseRoles,
    NULL AS DefaultSchema,
    NULL AS UserCreated
FROM sys.server_principals sp
WHERE sp.type IN ('S','U','G','C','K')
  AND sp.name NOT LIKE '##%'
  AND sp.name NOT LIKE 'NT %'
  AND sp.name NOT IN ('sa', 'public')
  AND NOT EXISTS (
      SELECT 1 
      FROM #UserRoles u 
      WHERE u.ServerLogin = sp.name 
        AND u.DatabaseName <> 'No database user found'
  );

-- Final result
SELECT 
    ServerLogin,
    LoginType,
    LoginStatus,
    DatabaseName,
    UserName,
    UserType,
    ISNULL(DatabaseRoles, '—') AS DatabaseRoles,
    DefaultSchema,
    UserCreated
FROM #UserRoles
ORDER BY 
    ServerLogin,
    CASE WHEN DatabaseName = 'No database user found' THEN 1 ELSE 0 END,
    DatabaseName,
    UserName;

-- Cleanup
DROP TABLE #UserRoles;