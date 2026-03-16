USE msdb;
GO

SELECT 
    j.name AS JobName,
    CASE 
        WHEN j.enabled = 1 AND EXISTS (
            SELECT 1 
            FROM msdb.dbo.sysjobschedules jsj 
            INNER JOIN msdb.dbo.sysschedules js ON jsj.schedule_id = js.schedule_id
            WHERE jsj.job_id = j.job_id AND js.enabled = 1
        ) THEN 'Yes'
        ELSE 'No'
    END AS IsScheduled,
    MAX(msdb.dbo.agent_datetime(h.run_date, h.run_time)) AS LastRunDateTime,
    CASE MAX(h.run_status)
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In Progress'
        ELSE 'Unknown'
    END AS LastExecutionStatus
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
GROUP BY j.job_id, j.name, j.enabled
ORDER BY j.name;