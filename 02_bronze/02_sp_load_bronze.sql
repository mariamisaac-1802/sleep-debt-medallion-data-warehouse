/*
=============================================================================
02_bronze/02_sp_load_bronze.sql
Purpose : bronze.load_bronze - INCREMENTAL load from staging (NO TRUNCATE).
Logic   :
  1. Type-cast staging with TRY_CAST (a bad value becomes NULL, never an error).
  2. De-duplicate the incoming batch on user_id.
  3. UPDATE existing users only when at least one attribute changed.
  4. INSERT users that are not yet in Bronze.
  5. Clean-up: if a user ever ends up with several rows, keep only the row
     with the HIGHEST bronze_id.
Re-running with the same staging data is idempotent (0 updates, 0 inserts).
=============================================================================
*/
USE SleepDebtDW;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_time     DATETIME2 = SYSDATETIME();
    DECLARE @staging_rows   INT, @batch_rows INT;
    DECLARE @updated        INT = 0, @inserted INT = 0, @dups_removed INT = 0;

    BEGIN TRY
        PRINT '>> bronze.load_bronze started';
        BEGIN TRANSACTION;

        SELECT @staging_rows = COUNT(*) FROM staging.sleep_debt_raw;

        -- 1 + 2. Type-cast and de-duplicate the incoming batch ---------------
        IF OBJECT_ID('tempdb..#src') IS NOT NULL DROP TABLE #src;

        ;WITH typed AS
        (
            SELECT
                user_id                  = UPPER(LTRIM(RTRIM(user_id))),
                age                      = TRY_CAST(age AS INT),
                gender                   = NULLIF(LTRIM(RTRIM(gender)), ''),
                occupation_type          = NULLIF(LTRIM(RTRIM(occupation_type)), ''),
                chronotype               = NULLIF(LTRIM(RTRIM(chronotype)), ''),
                bedtime_phone_minutes    = TRY_CAST(bedtime_phone_minutes AS INT),
                primary_bedtime_app      = NULLIF(LTRIM(RTRIM(primary_bedtime_app)), ''),
                screen_brightness_pct    = TRY_CAST(screen_brightness_pct AS INT),
                blue_light_filter_active = TRY_CAST(blue_light_filter_active AS BIT),
                caffeine_post_5pm_mg     = TRY_CAST(caffeine_post_5pm_mg AS INT),
                physical_activity_min    = TRY_CAST(physical_activity_min AS INT),
                sleep_latency_min        = TRY_CAST(sleep_latency_min AS DECIMAL(6,1)),
                total_sleep_hours        = TRY_CAST(total_sleep_hours AS DECIMAL(4,2)),
                deep_sleep_pct           = TRY_CAST(deep_sleep_pct AS DECIMAL(4,1)),
                rem_sleep_pct            = TRY_CAST(rem_sleep_pct AS DECIMAL(4,1)),
                morning_alarm_snoozes    = TRY_CAST(morning_alarm_snoozes AS INT),
                next_day_fatigue_score   = TRY_CAST(next_day_fatigue_score AS DECIMAL(3,1)),
                sleep_debt_category      = NULLIF(LTRIM(RTRIM(sleep_debt_category)), '')
            FROM staging.sleep_debt_raw
        ),
        ranked AS
        (
            SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY (SELECT NULL))
            FROM typed
            WHERE user_id IS NOT NULL AND user_id <> ''
        )
        SELECT user_id, age, gender, occupation_type, chronotype, bedtime_phone_minutes,
               primary_bedtime_app, screen_brightness_pct, blue_light_filter_active,
               caffeine_post_5pm_mg, physical_activity_min, sleep_latency_min,
               total_sleep_hours, deep_sleep_pct, rem_sleep_pct, morning_alarm_snoozes,
               next_day_fatigue_score, sleep_debt_category
        INTO #src
        FROM ranked
        WHERE rn = 1;

        SELECT @batch_rows = COUNT(*) FROM #src;

        -- 3. UPDATE changed users (EXCEPT is NULL-safe, unlike <>) -----------
        UPDATE b
        SET  b.age                      = s.age,
             b.gender                   = s.gender,
             b.occupation_type          = s.occupation_type,
             b.chronotype               = s.chronotype,
             b.bedtime_phone_minutes    = s.bedtime_phone_minutes,
             b.primary_bedtime_app      = s.primary_bedtime_app,
             b.screen_brightness_pct    = s.screen_brightness_pct,
             b.blue_light_filter_active = s.blue_light_filter_active,
             b.caffeine_post_5pm_mg     = s.caffeine_post_5pm_mg,
             b.physical_activity_min    = s.physical_activity_min,
             b.sleep_latency_min        = s.sleep_latency_min,
             b.total_sleep_hours        = s.total_sleep_hours,
             b.deep_sleep_pct           = s.deep_sleep_pct,
             b.rem_sleep_pct            = s.rem_sleep_pct,
             b.morning_alarm_snoozes    = s.morning_alarm_snoozes,
             b.next_day_fatigue_score   = s.next_day_fatigue_score,
             b.sleep_debt_category      = s.sleep_debt_category,
             b.bronze_updated_at        = SYSDATETIME()
        FROM bronze.sleep_debt_raw b
        JOIN #src s ON s.user_id = b.user_id
        WHERE EXISTS
        (
            SELECT s.age, s.gender, s.occupation_type, s.chronotype, s.bedtime_phone_minutes,
                   s.primary_bedtime_app, s.screen_brightness_pct, s.blue_light_filter_active,
                   s.caffeine_post_5pm_mg, s.physical_activity_min, s.sleep_latency_min,
                   s.total_sleep_hours, s.deep_sleep_pct, s.rem_sleep_pct,
                   s.morning_alarm_snoozes, s.next_day_fatigue_score, s.sleep_debt_category
            EXCEPT
            SELECT b.age, b.gender, b.occupation_type, b.chronotype, b.bedtime_phone_minutes,
                   b.primary_bedtime_app, b.screen_brightness_pct, b.blue_light_filter_active,
                   b.caffeine_post_5pm_mg, b.physical_activity_min, b.sleep_latency_min,
                   b.total_sleep_hours, b.deep_sleep_pct, b.rem_sleep_pct,
                   b.morning_alarm_snoozes, b.next_day_fatigue_score, b.sleep_debt_category
        );
        SET @updated = @@ROWCOUNT;

        -- 4. INSERT new users -------------------------------------------------
        INSERT INTO bronze.sleep_debt_raw
        (
            user_id, age, gender, occupation_type, chronotype, bedtime_phone_minutes,
            primary_bedtime_app, screen_brightness_pct, blue_light_filter_active,
            caffeine_post_5pm_mg, physical_activity_min, sleep_latency_min,
            total_sleep_hours, deep_sleep_pct, rem_sleep_pct, morning_alarm_snoozes,
            next_day_fatigue_score, sleep_debt_category
        )
        SELECT s.user_id, s.age, s.gender, s.occupation_type, s.chronotype, s.bedtime_phone_minutes,
               s.primary_bedtime_app, s.screen_brightness_pct, s.blue_light_filter_active,
               s.caffeine_post_5pm_mg, s.physical_activity_min, s.sleep_latency_min,
               s.total_sleep_hours, s.deep_sleep_pct, s.rem_sleep_pct, s.morning_alarm_snoozes,
               s.next_day_fatigue_score, s.sleep_debt_category
        FROM #src s
        WHERE NOT EXISTS (SELECT 1 FROM bronze.sleep_debt_raw b WHERE b.user_id = s.user_id);
        SET @inserted = @@ROWCOUNT;

        -- 5. Keep only the highest bronze_id per user_id ----------------------
        ;WITH d AS
        (
            SELECT rn = ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY bronze_id DESC)
            FROM bronze.sleep_debt_raw
        )
        DELETE FROM d WHERE rn > 1;
        SET @dups_removed = @@ROWCOUNT;

        COMMIT TRANSACTION;

        PRINT '>> Staging rows read          : ' + CAST(@staging_rows AS NVARCHAR(20));
        PRINT '>> Unique rows in batch       : ' + CAST(@batch_rows   AS NVARCHAR(20));
        PRINT '>> Rejected (no key/duplicate): ' + CAST(@staging_rows - @batch_rows AS NVARCHAR(20));
        PRINT '>> Rows updated               : ' + CAST(@updated      AS NVARCHAR(20));
        PRINT '>> Rows inserted              : ' + CAST(@inserted     AS NVARCHAR(20));
        PRINT '>> Old duplicates removed     : ' + CAST(@dups_removed AS NVARCHAR(20));
        PRINT '>> Duration (ms)              : ' + CAST(DATEDIFF(MILLISECOND, @start_time, SYSDATETIME()) AS NVARCHAR(20));
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        PRINT '!! bronze.load_bronze FAILED';
        PRINT '!! Error ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + ': ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO
