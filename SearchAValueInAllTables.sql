--==========Search Criteria Setup==============--
SET NOCOUNT ON
DECLARE @stringToFind VARCHAR(1000) = 'crystal19@adventure-works.com' -- What value?
DECLARE @dataTypes VARCHAR(1000) = 'char, nvarchar, varchar' -- What is the datatype of the value?
DECLARE @searcType BIT = 1 -- 0 = Like, 1 = Equal to (Exact match) -- What type of search you would like to put?

--SELECT DISTINCT name FROM sys.types --Data type list
--==========Search Criteria Setup==============--

DECLARE @schema SYSNAME
DECLARE @table SYSNAME
DECLARE @count INT
DECLARE @sqlCommand VARCHAR(8000)
DECLARE @where VARCHAR(8000)
DECLARE @columnName SYSNAME
DECLARE @columnType SYSNAME
DECLARE @object_id INT
SET @dataTypes = @dataTypes + ','

IF OBJECT_ID('tempdb..#temp') IS NOT NULL DROP TABLE #temp
CREATE TABLE #temp (ID INT IDENTITY(1,1), TableName SYSNAME, KeyName NVARCHAR(2000), KeyValue NVARCHAR(2000), ColumnName VARCHAR(256), SearchedStr NVARCHAR(MAX), Script NVARCHAR(1000))

DECLARE TAB_CURSOR CURSOR  FOR
SELECT   B.NAME      AS SCHEMANAME,
         A.NAME      AS TABLENAME,
         A.OBJECT_ID
FROM     sys.objects A
         INNER JOIN sys.schemas B
           ON A.SCHEMA_ID = B.SCHEMA_ID
WHERE    TYPE = 'U'
ORDER BY 1 

OPEN TAB_CURSOR 

FETCH NEXT FROM TAB_CURSOR
INTO @schema,
     @table,
     @object_id 

WHILE @@FETCH_STATUS = 0
  BEGIN
    DECLARE COL_CURSOR CURSOR FOR
    WITH CTE ([startPostion], [endPostion]) AS (
    SELECT
	   1 AS Start,
	   CHARINDEX(',', @dataTypes, 1) AS [endPostion] UNION ALL SELECT
	   [endPostion] + 1 AS [startPostion],
	   CHARINDEX(',', @dataTypes, [endPostion] + 1) AS [endPostion]
    FROM CTE
    WHERE [endPostion] < LEN(@dataTypes)
    )
    SELECT A.name, B.name
    FROM   sys.columns A
           INNER JOIN sys.types B
             ON A.SYSTEM_TYPE_ID = B.SYSTEM_TYPE_ID
    WHERE  OBJECT_ID = @object_id
           AND IS_COMPUTED = 0
           AND B.NAME IN (SELECT RTRIM(LTRIM(SUBSTRING(@dataTypes, [startPostion], [endPostion] - [startPostion]))) AS String FROM CTE) 

    OPEN COL_CURSOR 

    FETCH NEXT FROM COL_CURSOR
    INTO @columnName, @columnType

    WHILE @@FETCH_STATUS = 0
      BEGIN
        SET @sqlCommand =  ' SELECT '''+@table+''' AS TABLENAME, '
					+ ' COALESCE(STUFF((SELECT '' | '' + QUOTENAME(COLUMN_NAME)
					    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
					    WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + ''.'' + CONSTRAINT_NAME), ''IsPrimaryKey'') = 1 AND TABLE_NAME = '''+@table+''' AND TABLE_SCHEMA = '''+@schema+'''
					    FOR XML PATH(''''), TYPE).value(''.'', ''VARCHAR(MAX)''), 1, 3, ''''),(SELECT  QUOTENAME(name) FROM sys.identity_columns WHERE [object_id] = '+CAST(@object_id AS VARCHAR(10))+'), ''NO PK''), '

					+  COALESCE(
					   REPLACE(STUFF((SELECT ' | ' + 'CAST(' + QUOTENAME(COLUMN_NAME) + ' AS VARCHAR(1000))'
					   FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
					   WHERE OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + CONSTRAINT_NAME), 'IsPrimaryKey') = 1 AND TABLE_NAME = ''+@table+'' AND TABLE_SCHEMA = ''+@schema+''
					   FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 3, ''), '|', '+ '' | '' +')
					   , (SELECT '' + QUOTENAME(name) + '' FROM sys.identity_columns WHERE [object_id] = @object_id), '''NO PK''')  + ' AS PRIMARYKEYVALUE ,'

					+ '''' + @columnName+''' AS COLNAME, '
					+ QUOTENAME(@columnName)+' AS VALUE FROM '
					+ QUOTENAME(@schema) + '.' + QUOTENAME(@table) + ' (NOLOCK) '

		SET @searcType = CASE WHEN @searcType = 0 AND @columnType IN ('date', 'time', 'datetime2', 'datetimeoffset', 'smalldatetime', 'datetime')
						THEN  1 ELSE @searcType END

		SET @where = CASE WHEN @searcType = 0 THEN ' WHERE [' + @columnName + '] LIKE ''%' + @stringToFind + '%'''
					ELSE ' WHERE [' + @columnName + '] = ''' + @stringToFind + '''' END

	   --SELECT @table, @sqlCommand, @where

	   INSERT INTO #temp(TABLENAME, KeyName, KeyValue, ColumnName, SearchedStr)
        EXEC( @sqlCommand + @where) 

        SET @count = @@ROWCOUNT 

        IF @count > 0
          BEGIN
            PRINT @sqlCommand + @where
            PRINT '---============================---'
          END 

        FETCH NEXT FROM COL_CURSOR
        INTO @columnName, @columnType
      END 

    CLOSE COL_CURSOR
    DEALLOCATE COL_CURSOR 

    FETCH NEXT FROM TAB_CURSOR
    INTO @schema,
         @table,
         @object_id
  END 

CLOSE TAB_CURSOR
DEALLOCATE TAB_CURSOR

--UPDATE #temp SET Script = 'SELECT * FROM ' + QUOTENAME(TableName) + ' WHERE ' + KeyName + ' = ' + CAST(KeyValue AS NVARCHAR(2000))
--WHERE ISNULL(KeyValue, '') <> ''

SELECT * FROM #temp
