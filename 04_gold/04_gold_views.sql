/*
=============================================================================
04_gold/04_gold_views.sql
Purpose : Star schema for reporting (Power BI / Tableau / SQL).
          Dimensions : dim_user, dim_app, dim_sleep_debt_category,
                       dim_age_group, dim_screen_time_bucket
          Fact       : fact_sleep_record (grain = one row per user)
Note    : Gold contains VIEWS only - no data is stored here.
=============================================================================
*/
USE SleepDebtDW;
GO

-- ---------------------------------------------------------------------------
-- DIMENSIONS
-- ---------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.dim_user AS
SELECT
    u.user_key,
    u.user_id,
    u.age,
    u.age_group,
    u.gender,
    u.occupation_type,
    u.chronotype
FROM silver.dim_user u;
GO

CREATE OR ALTER VIEW gold.dim_app AS
SELECT
    a.app_key,
    a.app_name,
    a.app_category
FROM silver.dim_app a;
GO

CREATE OR ALTER VIEW gold.dim_sleep_debt_category AS
SELECT
    k.category_key,
    k.category_name,
    k.severity_rank
FROM silver.dim_sleep_debt_category k;
GO

-- Static, ordered helper dimensions (sort order makes BI charts read correctly)
CREATE OR ALTER VIEW gold.dim_age_group AS
SELECT age_group_key, age_group, sort_order
FROM (VALUES (1, N'18-24', 1),
             (2, N'25-34', 2),
             (3, N'35-44', 3),
             (4, N'45-54', 4),
             (5, N'55+',   5),
             (0, N'Under 18', 0)) AS v (age_group_key, age_group, sort_order);
GO

CREATE OR ALTER VIEW gold.dim_screen_time_bucket AS
SELECT screen_time_bucket_key, screen_time_bucket, min_minutes, max_minutes
FROM (VALUES (1, N'Low (<30 min)',          0,   29),
             (2, N'Moderate (30-59 min)',   30,   59),
             (3, N'High (60-119 min)',      60,  119),
             (4, N'Very High (120+ min)',  120, 1440)) AS v (screen_time_bucket_key, screen_time_bucket, min_minutes, max_minutes);
GO

-- ---------------------------------------------------------------------------
-- FACT
-- ---------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.fact_sleep_record AS
SELECT
    f.sleep_record_key,
    -- dimension keys
    f.user_key,
    f.app_key,
    f.category_key,
    ag.age_group_key,
    sb.screen_time_bucket_key,
    -- measures
    f.bedtime_phone_minutes,
    f.screen_brightness_pct,
    CAST(f.blue_light_filter_active AS INT) AS blue_light_filter_active,
    f.caffeine_post_5pm_mg,
    f.physical_activity_min,
    f.sleep_latency_min,
    f.total_sleep_hours,
    f.deep_sleep_pct,
    f.rem_sleep_pct,
    f.deep_rem_total_pct,
    f.morning_alarm_snoozes,
    f.next_day_fatigue_score,
    -- flags (0/1 so they can be summed / averaged directly)
    CAST(f.has_caffeine_flag  AS INT) AS has_caffeine_flag,
    CAST(f.high_fatigue_flag  AS INT) AS high_fatigue_flag
FROM silver.fact_sleep_record f
JOIN silver.dim_user u              ON u.user_key = f.user_key
JOIN gold.dim_age_group ag          ON ag.age_group = u.age_group
JOIN gold.dim_screen_time_bucket sb ON sb.screen_time_bucket = f.screen_time_bucket;
GO
