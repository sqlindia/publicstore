USE AdventureWorks2012
GO
 
IF OBJECT_ID('tempdb..#t') IS NOT NULL DROP TABLE #t
CREATE TABLE #t (ID INT IDENTITY(1,1))
 
--//START: Generating table structure dynamically
DECLARE @spName sysname = 'uspGetEmployeeManagers'
, @columns NVARCHAR(MAX), @sql NVARCHAR(MAX)
SELECT @columns = STUFF((SELECT ', ' + QUOTENAME(name) + ' ' + system_type_name + ' NULL'
                    FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID(@spName), 0) AS a ORDER BY a.column_ordinal
                    FOR XML PATH(''), TYPE).value('.[1]', 'NVARCHAR(MAX)'), 1, 2, '');
 
SET @sql = N'ALTER TABLE #t ADD ' + @columns
EXEC sp_executesql @sql
--//END: Generating table structure dynamically
 
--//Doing insert
INSERT INTO #t
exec uspGetEmployeeManagers @BusinessEntityID = 3
 
SELECT * FROM #t
