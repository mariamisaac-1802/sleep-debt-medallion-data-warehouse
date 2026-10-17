/*
=============================================================================
01_staging/01_ddl_staging.sql
Purpose : Landing table that mirrors the cleaned CSV 1:1.
Rule    : ALL columns are NVARCHAR(255) so that no ingestion row can fail
          because of a data-type problem. Typing happens in Bronze.
=============================================================================
*/
USE SleepDebtDW;
GO

IF OBJECT_ID(N'staging.sleep_debt_raw', N'U') IS NOT NULL
    DROP TABLE staging.sleep_debt_raw;
GO

CREATE TABLE staging.sleep_debt_raw
(
    user_id                     NVARCHAR(255),
    age                         NVARCHAR(255),
    gender                      NVARCHAR(255),
    occupation_type             NVARCHAR(255),
    chronotype                  NVARCHAR(255),
    bedtime_phone_minutes       NVARCHAR(255),
    primary_bedtime_app         NVARCHAR(255),
    screen_brightness_pct       NVARCHAR(255),
    blue_light_filter_active    NVARCHAR(255),
    caffeine_post_5pm_mg        NVARCHAR(255),
    physical_activity_min       NVARCHAR(255),
    sleep_latency_min           NVARCHAR(255),
    total_sleep_hours           NVARCHAR(255),
    deep_sleep_pct              NVARCHAR(255),
    rem_sleep_pct               NVARCHAR(255),
    morning_alarm_snoozes       NVARCHAR(255),
    next_day_fatigue_score      NVARCHAR(255),
    sleep_debt_category         NVARCHAR(255)
);
GO
