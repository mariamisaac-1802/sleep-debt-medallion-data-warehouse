/*
=============================================================================
02_bronze/01_ddl_bronze.sql
Purpose : Bronze table with NATIVE data types plus tracking columns.
          bronze_id (IDENTITY) is the surrogate/tracking key. Business key
          is user_id. Columns are nullable here on purpose: Bronze keeps
          what it can type; Silver enforces strict NOT NULL rules.
=============================================================================
*/
USE SleepDebtDW;
GO

IF OBJECT_ID(N'bronze.sleep_debt_raw', N'U') IS NOT NULL
    DROP TABLE bronze.sleep_debt_raw;
GO

CREATE TABLE bronze.sleep_debt_raw
(
    bronze_id                   INT IDENTITY(1,1) NOT NULL,
    user_id                     NVARCHAR(20)   NOT NULL,
    age                         INT            NULL,
    gender                      NVARCHAR(50)   NULL,
    occupation_type             NVARCHAR(100)  NULL,
    chronotype                  NVARCHAR(50)   NULL,
    bedtime_phone_minutes       INT            NULL,
    primary_bedtime_app         NVARCHAR(100)  NULL,
    screen_brightness_pct       INT            NULL,
    blue_light_filter_active    BIT            NULL,
    caffeine_post_5pm_mg        INT            NULL,
    physical_activity_min       INT            NULL,
    sleep_latency_min           DECIMAL(6,1)   NULL,
    total_sleep_hours           DECIMAL(4,2)   NULL,
    deep_sleep_pct              DECIMAL(4,1)   NULL,
    rem_sleep_pct               DECIMAL(4,1)   NULL,
    morning_alarm_snoozes       INT            NULL,
    next_day_fatigue_score      DECIMAL(3,1)   NULL,
    sleep_debt_category         NVARCHAR(50)   NULL,
    bronze_loaded_at            DATETIME2      NOT NULL CONSTRAINT df_bronze_loaded_at  DEFAULT SYSDATETIME(),
    bronze_updated_at           DATETIME2      NULL,
    CONSTRAINT pk_bronze_sleep_debt_raw PRIMARY KEY CLUSTERED (bronze_id)
);
GO

-- Supports the upsert join and the "highest bronze_id per user" lookups
CREATE NONCLUSTERED INDEX ix_bronze_sleep_debt_raw_user_id
    ON bronze.sleep_debt_raw (user_id, bronze_id DESC);
GO
