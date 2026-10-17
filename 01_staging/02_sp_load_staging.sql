/*
=============================================================================
01_staging/02_sp_load_staging.sql
Purpose : staging.load_staging - TRUNCATE + BULK INSERT of the cleaned CSV.
Usage   : EXEC staging.load_staging @file_path = N'C:\SleepDebtDW\data\bedtime_screentime_sleep_debt_clean.csv';
Notes   : * The file must be readable by the SQL Server service account
            (path is resolved on the SERVER, not on your PC).
          * The cleaned CSV is written by the Python script with '\n' line
            endings and UTF-8 encoding, hence ROWTERMINATOR = '0x0a'.
          * FORMAT = 'CSV' requires SQL Server 2017 or later.
=============================================================================
*/
USE SleepDebtDW;
GO

CREATE OR ALTER PROCEDURE staging.load_staging
    @file_path NVARCHAR(500) = N'C:\SleepDebtDW\data\bedtime_screentime_sleep_debt_clean.csv'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_time DATETIME2 = SYSDATETIME();
    DECLARE @rows INT;
    DECLARE @sql NVARCHAR(MAX);

    BEGIN TRY
        PRINT '>> staging.load_staging started';
        PRINT '>> Source file: ' + @file_path;

        -- Truncate and insert: staging always mirrors the latest file
        TRUNCATE TABLE staging.sleep_debt_raw;

        -- BULK INSERT does not accept a variable path, so dynamic SQL is required
        SET @sql = N'
            BULK INSERT staging.sleep_debt_raw
            FROM ' + QUOTENAME(@file_path, '''') + N'
            WITH (
                FORMAT          = ''CSV'',
                FIRSTROW        = 2,
                FIELDTERMINATOR = '','',
                FIELDQUOTE      = ''"'',
                ROWTERMINATOR   = ''0x0a'',
                CODEPAGE        = ''65001'',
                TABLOCK
            );';
        EXEC sys.sp_executesql @sql;

        SELECT @rows = COUNT(*) FROM staging.sleep_debt_raw;

        PRINT '>> Rows loaded into staging.sleep_debt_raw: ' + CAST(@rows AS NVARCHAR(20));
        PRINT '>> Duration (ms): ' + CAST(DATEDIFF(MILLISECOND, @start_time, SYSDATETIME()) AS NVARCHAR(20));
    END TRY
    BEGIN CATCH
        PRINT '!! staging.load_staging FAILED';
        PRINT '!! Error ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + ': ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO
