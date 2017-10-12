SELECT bs.server_name           AS Server,-- Server name 
       bs.database_name         AS DatabseName,-- Database name 
       -- Return backup compatibility level 
       recovery_model           AS Recoverymodel,-- Database recovery model 
       CASE bs.type 
         WHEN 'D' THEN 'Full' 
         WHEN 'I' THEN 'Differential' 
         WHEN 'L' THEN 'Log' 
         WHEN 'F' THEN 'File or filegroup' 
         WHEN 'G' THEN 'Differential file' 
         WHEN 'P' THEN 'P' 
         WHEN 'Q' THEN 'Differential partial' 
       END                      AS BackupType,-- Type of database baclup 
       bs.backup_start_date     AS BackupstartDate,-- Backup start date 
       bs.backup_finish_date    AS BackupFinishDate,-- Backup finish date 
		CAST(DATEDIFF(second, bs.backup_start_date,
		bs.backup_finish_date) AS VARCHAR(100)) + ' sec' time_taken ,
       CASE device_type 
         WHEN 2 THEN 'Disk - Temporary' 
         WHEN 102 THEN 'Disk - Permanent' 
         WHEN 5 THEN 'Tape - Temporary' 
         WHEN 105 THEN 'Tape - Temporary' 
         ELSE 'Other Device' 
       END                      AS DeviceType,-- Device type 
       bs.backup_size           AS [BackupSize(In bytes)]
-- Compressed backup size (In bytes) 
FROM   msdb.dbo.backupset bs 
       INNER JOIN msdb.dbo.backupmediafamily bmf 
               ON ( bs.media_set_id = bmf.media_set_id ) 
--WHERE CAST(backup_finish_date AS DATE) = '2015-05-06' and database_name = DB_NAME()
ORDER  BY bs.database_name, backup_finish_date
GO 

;WITH CTE AS (SELECT --TOP 100
s.database_name,
m.physical_device_name,
CAST(CAST(s.backup_size / 1000000 AS INT) AS int) AS Size,
CAST(DATEDIFF(second, s.backup_start_date,
s.backup_finish_date) AS INT) time_taken,
s.backup_start_date,
CAST(s.first_lsn AS VARCHAR(50)) AS first_lsn,
CAST(s.last_lsn AS VARCHAR(50)) AS last_lsn,
CASE s.[type]
WHEN 'D' THEN 'Full'
WHEN 'I' THEN 'Differential'
WHEN 'L' THEN 'Transaction Log'
END AS backup_type,
s.server_name,
s.recovery_model
FROM msdb.dbo.backupset s
INNER JOIN msdb.dbo.backupmediafamily m ON s.media_set_id = m.media_set_id
--WHERE 
--s.database_name = DB_NAME() AND -- Remove this line for all the database
--CAST(backup_start_date AS DATE) = '2017-10-01'
--ORDER BY backup_start_date DESC--, backup_finish_date
), CTE2 AS (SELECT database_name as DatabaseName
, SUM(Size) as TotalBackupSize
, SUM(time_taken) TotalTimeTaken
, backup_type as BackupType
, COUNT(1) BackupCounts
, CAST(backup_start_date AS DATE) AS [date] FROM CTE
GROUP BY database_name,backup_type,CAST(backup_start_date AS DATE)
)

SELECT 
DatabaseName as [Database Name]
, CAST(TotalBackupSize AS VARCHAR(20)) + ' MB' [Total Backup Size\Day]
, CAST(TotalTimeTaken AS VARCHAR(20)) + ' sec' [Total Time Taken\Day]
, BackupType as [Backup Type]
, BackupCounts as [Backup Counts\Day]
, [Date]
FROM CTE2
