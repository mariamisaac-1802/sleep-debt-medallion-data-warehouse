/*
=============================================================================
03_silver/02_sp_load_silver.sql
Purpose : silver.load_silver - final cleansing, enrichment and business rules.
Source  : latest Bronze row per user_id (highest bronze_id).
Steps   : 1. Pick latest row per user, cleanse text, apply validity rules.
          2. Upsert dimensions (dim_user, dim_app, dim_sleep_debt_category).
          3. Rebuild the fact table (dimension surrogate keys stay stable).
Business rules applied
  * age_group          : 18-24 / 25-34 / 35-44 / 45-54 / 55+
  * screen_time_bucket : Low (<30 min) / Moderate (30-59) / High (60-119) / Very High (120+)
  * has_caffeine_flag  : caffeine after 5pm > 0 mg
  * deep_rem_total_pct : deep_sleep_pct + rem_sleep_pct
  * high_fatigue_flag  : next_day_fatigue_score >= 7
  * app_category       : Social Media / Video & Streaming / Communication / News & Reading
Rows failing a mandatory-field or range rule are rejected (counted, not loaded).
=============================================================================
*/
USE SleepDebtDW;
GO

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_time DATETIME2 = SYSDATETIME();
    DECLARE @bronze_users INT, @valid_rows INT, @fact_rows INT;

    BEGIN TRY
        PRINT '>> silver.load_silver started';
        BEGIN TRANSACTION;

        -- 1. Latest Bronze row per user, cleansed + validated -----------------
        IF OBJECT_ID('tempdb..#clean') IS NOT NULL DROP TABLE #clean;

        ;WITH latest AS
        (
            SELECT b.*, rn = ROW_NUMBER() OVER (PARTITION BY b.user_id ORDER BY b.bronze_id DESC)
            FROM bronze.sleep_debt_raw b
        )
        SELECT
            source_bronze_id         = bronze_id,
            user_id                  = UPPER(LTRIM(RTRIM(user_id))),
            age,
            gender                   = LTRIM(RTRIM(gender)),
            occupation_type          = LTRIM(RTRIM(occupation_type)),
            chronotype               = LTRIM(RTRIM(chronotype)),
            primary_bedtime_app      = LTRIM(RTRIM(primary_bedtime_app)),
            sleep_debt_category      = LTRIM(RTRIM(sleep_debt_category)),
            bedtime_phone_minutes, screen_brightness_pct, blue_light_filter_active,
            caffeine_post_5pm_mg, physical_activity_min, sleep_latency_min,
            total_sleep_hours, deep_sleep_pct, rem_sleep_pct,
            morning_alarm_snoozes, next_day_fatigue_score,
            age_group = CASE WHEN age < 18 THEN N'Under 18'
                             WHEN age BETWEEN 18 AND 24 THEN N'18-24'
                             WHEN age BETWEEN 25 AND 34 THEN N'25-34'
                             WHEN age BETWEEN 35 AND 44 THEN N'35-44'
                             WHEN age BETWEEN 45 AND 54 THEN N'45-54'
                             ELSE N'55+' END,
            screen_time_bucket = CASE WHEN bedtime_phone_minutes < 30  THEN N'Low (<30 min)'
                                      WHEN bedtime_phone_minutes < 60  THEN N'Moderate (30-59 min)'
                                      WHEN bedtime_phone_minutes < 120 THEN N'High (60-119 min)'
                                      ELSE N'Very High (120+ min)' END,
            has_caffeine_flag  = CAST(CASE WHEN caffeine_post_5pm_mg > 0 THEN 1 ELSE 0 END AS BIT),
            deep_rem_total_pct = CAST(deep_sleep_pct + rem_sleep_pct AS DECIMAL(5,1)),
            high_fatigue_flag  = CAST(CASE WHEN next_day_fatigue_score >= 7 THEN 1 ELSE 0 END AS BIT)
        INTO #clean
        FROM latest
        WHERE rn = 1
          -- mandatory fields
          AND age IS NOT NULL AND gender IS NOT NULL AND occupation_type IS NOT NULL
          AND chronotype IS NOT NULL AND primary_bedtime_app IS NOT NULL
          AND sleep_debt_category IS NOT NULL AND bedtime_phone_minutes IS NOT NULL
          AND screen_brightness_pct IS NOT NULL AND blue_light_filter_active IS NOT NULL
          AND caffeine_post_5pm_mg IS NOT NULL AND physical_activity_min IS NOT NULL
          AND sleep_latency_min IS NOT NULL AND total_sleep_hours IS NOT NULL
          AND deep_sleep_pct IS NOT NULL AND rem_sleep_pct IS NOT NULL
          AND morning_alarm_snoozes IS NOT NULL AND next_day_fatigue_score IS NOT NULL
          -- validity ranges (mirror the Silver CHECK constraints)
          AND age BETWEEN 16 AND 100
          AND bedtime_phone_minutes BETWEEN 0 AND 1440
          AND screen_brightness_pct BETWEEN 0 AND 100
          AND caffeine_post_5pm_mg >= 0 AND physical_activity_min >= 0 AND sleep_latency_min >= 0
          AND total_sleep_hours BETWEEN 0 AND 24
          AND deep_sleep_pct BETWEEN 0 AND 100 AND rem_sleep_pct BETWEEN 0 AND 100
          AND deep_sleep_pct + rem_sleep_pct <= 100
          AND morning_alarm_snoozes >= 0
          AND next_day_fatigue_score BETWEEN 1 AND 10;

        SELECT @bronze_users = COUNT(DISTINCT user_id) FROM bronze.sleep_debt_raw;
        SELECT @valid_rows   = COUNT(*) FROM #clean;

        -- 2a. dim_user: update changed, insert new ------------------------------
        UPDATE d
        SET d.age = c.age, d.age_group = c.age_group, d.gender = c.gender,
            d.occupation_type = c.occupation_type, d.chronotype = c.chronotype,
            d.silver_loaded_at = SYSDATETIME()
        FROM silver.dim_user d
        JOIN #clean c ON c.user_id = d.user_id
        WHERE EXISTS (SELECT c.age, c.gender, c.occupation_type, c.chronotype
                      EXCEPT
                      SELECT d.age, d.gender, d.occupation_type, d.chronotype);

        INSERT INTO silver.dim_user (user_id, age, age_group, gender, occupation_type, chronotype)
        SELECT c.user_id, c.age, c.age_group, c.gender, c.occupation_type, c.chronotype
        FROM #clean c
        WHERE NOT EXISTS (SELECT 1 FROM silver.dim_user d WHERE d.user_id = c.user_id);

        -- 2b. dim_app --------------------------------------------------------------
        INSERT INTO silver.dim_app (app_name, app_category)
        SELECT DISTINCT c.primary_bedtime_app,
               CASE WHEN c.primary_bedtime_app IN (N'TikTok / Reels', N'Instagram / Reddit')      THEN N'Social Media'
                    WHEN c.primary_bedtime_app IN (N'YouTube', N'Streaming (Netflix/Hulu)')       THEN N'Video & Streaming'
                    WHEN c.primary_bedtime_app = N'Messaging / Chat'                              THEN N'Communication'
                    WHEN c.primary_bedtime_app = N'News / Reading'                                THEN N'News & Reading'
                    ELSE N'Other' END
        FROM #clean c
        WHERE NOT EXISTS (SELECT 1 FROM silver.dim_app a WHERE a.app_name = c.primary_bedtime_app);

        -- 2c. dim_sleep_debt_category ------------------------------------------------
        INSERT INTO silver.dim_sleep_debt_category (category_name, severity_rank)
        SELECT DISTINCT c.sleep_debt_category,
               CASE c.sleep_debt_category
                    WHEN N'Optimal Recovery'  THEN 1
                    WHEN N'Mild Deficit'      THEN 2
                    WHEN N'Moderate Debt'     THEN 3
                    WHEN N'Severe Sleep Debt' THEN 4
                    ELSE 0 END
        FROM #clean c
        WHERE NOT EXISTS (SELECT 1 FROM silver.dim_sleep_debt_category k WHERE k.category_name = c.sleep_debt_category);

        -- 3. Fact: full rebuild from the validated latest-Bronze set ----------------
        DELETE FROM silver.fact_sleep_record;

        INSERT INTO silver.fact_sleep_record
        (
            user_key, app_key, category_key,
            bedtime_phone_minutes, screen_brightness_pct, blue_light_filter_active,
            caffeine_post_5pm_mg, physical_activity_min, sleep_latency_min,
            total_sleep_hours, deep_sleep_pct, rem_sleep_pct,
            morning_alarm_snoozes, next_day_fatigue_score,
            screen_time_bucket, has_caffeine_flag, deep_rem_total_pct, high_fatigue_flag,
            source_bronze_id
        )
        SELECT u.user_key, a.app_key, k.category_key,
               c.bedtime_phone_minutes, c.screen_brightness_pct, c.blue_light_filter_active,
               c.caffeine_post_5pm_mg, c.physical_activity_min, c.sleep_latency_min,
               c.total_sleep_hours, c.deep_sleep_pct, c.rem_sleep_pct,
               c.morning_alarm_snoozes, c.next_day_fatigue_score,
               c.screen_time_bucket, c.has_caffeine_flag, c.deep_rem_total_pct, c.high_fatigue_flag,
               c.source_bronze_id
        FROM #clean c
        JOIN silver.dim_user u                 ON u.user_id       = c.user_id
        JOIN silver.dim_app a                  ON a.app_name      = c.primary_bedtime_app
        JOIN silver.dim_sleep_debt_category k  ON k.category_name = c.sleep_debt_category;
        SET @fact_rows = @@ROWCOUNT;

        COMMIT TRANSACTION;

        PRINT '>> Unique users in Bronze        : ' + CAST(@bronze_users AS NVARCHAR(20));
        PRINT '>> Rows passing Silver rules      : ' + CAST(@valid_rows   AS NVARCHAR(20));
        PRINT '>> Rows rejected                  : ' + CAST(@bronze_users - @valid_rows AS NVARCHAR(20));
        PRINT '>> Rows in fact_sleep_record      : ' + CAST(@fact_rows    AS NVARCHAR(20));
        PRINT '>> Duration (ms)                  : ' + CAST(DATEDIFF(MILLISECOND, @start_time, SYSDATETIME()) AS NVARCHAR(20));
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        PRINT '!! silver.load_silver FAILED';
        PRINT '!! Error ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + ': ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO
