-----------------------------
-- Set active database
-----------------------------
USE [Website Funnel]
GO

----------------------------------
-- Merge datasets and create joins
----------------------------------
DROP TABLE IF EXISTS funnel_data_merged_stg
GO

DROP TABLE IF EXISTS funnel_data_merged
GO

SELECT *
INTO funnel_data_merged_stg
FROM home_page_table
UNION ALL
SELECT * 
FROM payment_confirmation_table
UNION ALL
SELECT *
FROM payment_page_table
UNION ALL
SELECT *
FROM search_page_table
GO

SELECT u.user_id, u.date, u.device, u.sex, stg.page
INTO funnel_data_merged
FROM user_table u
LEFT JOIN funnel_data_merged_stg stg ON u.user_id = stg.user_id
GO

-----------------------------------
-- Remove records with NULL values
-----------------------------------
DECLARE @SQL_REMOVE_NULLS NVARCHAR(MAX) = '';
DECLARE @TABLE_REMOVE_NULLS NVARCHAR(MAX) = 'funnel_data_merged';

SELECT @SQL_REMOVE_NULLS = @SQL_REMOVE_NULLS + 
    CASE WHEN @SQL_REMOVE_NULLS = '' THEN '' ELSE ' OR ' END +
    QUOTENAME(COLUMN_NAME) + ' IS NULL'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = @TABLE_REMOVE_NULLS;

SET @SQL_REMOVE_NULLS = 'DELETE FROM ' + @TABLE_REMOVE_NULLS + ' WHERE ' + @SQL_REMOVE_NULLS;

EXEC sp_executesql @SQL_REMOVE_NULLS;

---------------------------------------------
-- Bulk export to CSV
---------------------------------------------
-- Enable advanced options to use xp_cmdshell
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
GO

DECLARE @TableName NVARCHAR(128) = 'funnel_data_merged';
DECLARE @SchemaName NVARCHAR(128) = 'dbo';
DECLARE @DbName NVARCHAR(128) = 'Website Funnel'
DECLARE @OutputPath NVARCHAR(256) = 'E:\backup17092018\Myappdir\Myprojects\Data Science\Portfolio Projects\190 Sales Funnel Analysis\funnel_data_merged.csv';

-- Generate dynamic SQL to create headers and cast all columns to VARCHAR
DECLARE @SQL NVARCHAR(MAX);
SELECT @SQL = 
    'SELECT ''' + STRING_AGG(COLUMN_NAME, ''',''') + ''' UNION ALL ' +
    'SELECT ' + 
    STRING_AGG(
        CASE 
            WHEN DATA_TYPE IN ('varchar','nvarchar','char','nchar','text','ntext') 
            THEN 'ISNULL(' + QUOTENAME(COLUMN_NAME) + ','''')'
            ELSE 'CAST(ISNULL(' + QUOTENAME(COLUMN_NAME) + ','''') AS NVARCHAR(MAX))'
        END, 
        ', '
    ) +
    ' FROM ' + QUOTENAME(@DbName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName)
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = @TableName AND TABLE_SCHEMA = @SchemaName;

-- Execute BCP
DECLARE @BCPCommand NVARCHAR(4000) = 'bcp "' + REPLACE(@SQL, '"', '""') + '" queryout "' + @OutputPath + '" -c -t, -T -S ' + @@SERVERNAME;

EXEC xp_cmdshell @BCPCommand;

-- Disable xp_cmdshell when done (for security)
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;
GO