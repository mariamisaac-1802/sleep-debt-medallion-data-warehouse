/*
=============================================================================
05_analytics_queries.sql
Purpose : Business questions answered from the Gold star schema.
=============================================================================
*/
USE SleepDebtDW;
GO

-- Q1. Overall KPIs ------------------------------------------------------------
SELECT
    COUNT(*)                                              AS total_users,
    ROUND(AVG(total_sleep_hours), 2)                      AS avg_sleep_hours,
    ROUND(AVG(bedtime_phone_minutes), 1)                  AS avg_phone_min_before_bed,
    ROUND(AVG(sleep_latency_min), 1)                      AS avg_sleep_latency_min,
    ROUND(AVG(next_day_fatigue_score), 2)                 AS avg_fatigue_score,
    ROUND(100.0 * AVG(CAST(high_fatigue_flag AS FLOAT)), 1) AS pct_high_fatigue
FROM gold.fact_sleep_record;
GO

-- Q2. Sleep debt category distribution ----------------------------------------
SELECT
    k.category_name,
    COUNT(*)                                              AS users,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)    AS pct_of_users,
    ROUND(AVG(f.total_sleep_hours), 2)                    AS avg_sleep_hours
FROM gold.fact_sleep_record f
JOIN gold.dim_sleep_debt_category k ON k.category_key = f.category_key
GROUP BY k.category_name, k.severity_rank
ORDER BY k.severity_rank;
GO

-- Q3. Does more bedtime screen time mean worse sleep? -------------------------
SELECT
    sb.screen_time_bucket,
    COUNT(*)                                              AS users,
    ROUND(AVG(f.total_sleep_hours), 2)                    AS avg_sleep_hours,
    ROUND(AVG(f.sleep_latency_min), 1)                    AS avg_sleep_latency_min,
    ROUND(AVG(f.deep_sleep_pct), 1)                       AS avg_deep_sleep_pct,
    ROUND(AVG(f.next_day_fatigue_score), 2)               AS avg_fatigue_score
FROM gold.fact_sleep_record f
JOIN gold.dim_screen_time_bucket sb ON sb.screen_time_bucket_key = f.screen_time_bucket_key
GROUP BY sb.screen_time_bucket, sb.screen_time_bucket_key
ORDER BY sb.screen_time_bucket_key;
GO

-- Q4. Screen time bucket x sleep debt category (share of severe debt) ---------
SELECT
    sb.screen_time_bucket,
    COUNT(*)                                                                      AS users,
    ROUND(100.0 * SUM(CASE WHEN k.severity_rank >= 3 THEN 1 ELSE 0 END) / COUNT(*), 1)
                                                                                  AS pct_moderate_or_severe_debt
FROM gold.fact_sleep_record f
JOIN gold.dim_screen_time_bucket sb ON sb.screen_time_bucket_key = f.screen_time_bucket_key
JOIN gold.dim_sleep_debt_category k ON k.category_key = f.category_key
GROUP BY sb.screen_time_bucket, sb.screen_time_bucket_key
ORDER BY sb.screen_time_bucket_key;
GO

-- Q5. Blue light filter: on vs off --------------------------------------------
SELECT
    CASE f.blue_light_filter_active WHEN 1 THEN 'Filter ON' ELSE 'Filter OFF' END AS blue_light_filter,
    COUNT(*)                                              AS users,
    ROUND(AVG(f.sleep_latency_min), 1)                    AS avg_sleep_latency_min,
    ROUND(AVG(f.total_sleep_hours), 2)                    AS avg_sleep_hours,
    ROUND(AVG(f.deep_sleep_pct), 1)                       AS avg_deep_sleep_pct
FROM gold.fact_sleep_record f
GROUP BY f.blue_light_filter_active;
GO

-- Q6. Which bedtime apps are linked to the worst sleep? -----------------------
SELECT
    a.app_category,
    a.app_name,
    COUNT(*)                                              AS users,
    ROUND(AVG(f.bedtime_phone_minutes), 1)                AS avg_phone_min,
    ROUND(AVG(f.total_sleep_hours), 2)                    AS avg_sleep_hours,
    ROUND(AVG(f.next_day_fatigue_score), 2)               AS avg_fatigue_score
FROM gold.fact_sleep_record f
JOIN gold.dim_app a ON a.app_key = f.app_key
GROUP BY a.app_category, a.app_name
ORDER BY avg_sleep_hours ASC;
GO

-- Q7. Chronotype x occupation: who sleeps least? ------------------------------
SELECT
    u.chronotype,
    u.occupation_type,
    COUNT(*)                                              AS users,
    ROUND(AVG(f.total_sleep_hours), 2)                    AS avg_sleep_hours,
    ROUND(AVG(f.morning_alarm_snoozes), 2)                AS avg_snoozes
FROM gold.fact_sleep_record f
JOIN gold.dim_user u ON u.user_key = f.user_key
GROUP BY u.chronotype, u.occupation_type
ORDER BY avg_sleep_hours ASC;
GO

-- Q8. Late caffeine impact -----------------------------------------------------
SELECT
    CASE f.has_caffeine_flag WHEN 1 THEN 'Caffeine after 5pm' ELSE 'No late caffeine' END AS caffeine_group,
    COUNT(*)                                              AS users,
    ROUND(AVG(f.sleep_latency_min), 1)                    AS avg_sleep_latency_min,
    ROUND(AVG(f.total_sleep_hours), 2)                    AS avg_sleep_hours,
    ROUND(AVG(f.deep_sleep_pct), 1)                       AS avg_deep_sleep_pct
FROM gold.fact_sleep_record f
GROUP BY f.has_caffeine_flag;
GO

-- Q9. Age group profile ---------------------------------------------------------
SELECT
    ag.age_group,
    COUNT(*)                                              AS users,
    ROUND(AVG(f.total_sleep_hours), 2)                    AS avg_sleep_hours,
    ROUND(AVG(f.bedtime_phone_minutes), 1)                AS avg_phone_min,
    ROUND(100.0 * AVG(CAST(f.high_fatigue_flag AS FLOAT)), 1) AS pct_high_fatigue
FROM gold.fact_sleep_record f
JOIN gold.dim_age_group ag ON ag.age_group_key = f.age_group_key
GROUP BY ag.age_group, ag.sort_order
ORDER BY ag.sort_order;
GO

-- Q10. Physical activity vs sleep (activity quartiles) --------------------------
SELECT
    activity_quartile,
    COUNT(*)                                              AS users,
    MIN(physical_activity_min)                            AS min_activity_min,
    MAX(physical_activity_min)                            AS max_activity_min,
    ROUND(AVG(total_sleep_hours), 2)                      AS avg_sleep_hours,
    ROUND(AVG(sleep_latency_min), 1)                      AS avg_sleep_latency_min
FROM (
    SELECT *, NTILE(4) OVER (ORDER BY physical_activity_min) AS activity_quartile
    FROM gold.fact_sleep_record
) q
GROUP BY activity_quartile
ORDER BY activity_quartile;
GO
