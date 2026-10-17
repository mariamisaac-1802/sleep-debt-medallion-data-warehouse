/*
=============================================================================
00_init_database.sql
Purpose : Drop and re-create the SleepDebtDW database and create the four
          Medallion schemas (staging, bronze, silver, gold).
Engine  : SQL Server (T-SQL)
WARNING : Destroys the existing SleepDebtDW database if it exists.
=============================================================================
*/
USE master;
GO

IF DB_ID(N'SleepDebtDW') IS NOT NULL
BEGIN
    ALTER DATABASE SleepDebtDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SleepDebtDW;
END
GO

CREATE DATABASE SleepDebtDW;
GO

USE SleepDebtDW;
GO

CREATE SCHEMA staging;
GO
CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO

PRINT 'SleepDebtDW created with schemas: staging, bronze, silver, gold.';
GO
