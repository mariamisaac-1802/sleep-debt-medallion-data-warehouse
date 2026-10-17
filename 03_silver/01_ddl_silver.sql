/*
=============================================================================
03_silver/01_ddl_silver.sql
Purpose : Cleansed, constrained production tables (3NF-style dimensions plus
          one user-grain fact). Strict PK / FK / NOT NULL / CHECK / UNIQUE.
Grain   : fact_sleep_record = one row per user (the source has no date column).
=============================================================================
*/
USE SleepDebtDW;
GO

-- Drop in dependency order (fact first)
IF OBJECT_ID(N'silver.fact_sleep_record', N'U')        IS NOT NULL DROP TABLE silver.fact_sleep_record;
IF OBJECT_ID(N'silver.dim_user', N'U')                 IS NOT NULL DROP TABLE silver.dim_user;
IF OBJECT_ID(N'silver.dim_app', N'U')                  IS NOT NULL DROP TABLE silver.dim_app;
IF OBJECT_ID(N'silver.dim_sleep_debt_category', N'U')  IS NOT NULL DROP TABLE silver.dim_sleep_debt_category;
GO

-- ---------------------------------------------------------------------------
CREATE TABLE silver.dim_user
(
    user_key         INT IDENTITY(1,1) NOT NULL,
    user_id          NVARCHAR(20)  NOT NULL,
    age              INT           NOT NULL,
    age_group        NVARCHAR(10)  NOT NULL,
    gender           NVARCHAR(50)  NOT NULL,
    occupation_type  NVARCHAR(100) NOT NULL,
    chronotype       NVARCHAR(50)  NOT NULL,
    silver_loaded_at DATETIME2     NOT NULL CONSTRAINT df_silver_dim_user_loaded DEFAULT SYSDATETIME(),
    CONSTRAINT pk_silver_dim_user        PRIMARY KEY CLUSTERED (user_key),
    CONSTRAINT uq_silver_dim_user_id     UNIQUE (user_id),
    CONSTRAINT ck_silver_dim_user_age    CHECK (age BETWEEN 16 AND 100),
    CONSTRAINT ck_silver_dim_user_agegrp CHECK (age_group IN (N'18-24', N'25-34', N'35-44', N'45-54', N'55+', N'Under 18'))
);
GO

CREATE TABLE silver.dim_app
(
    app_key          INT IDENTITY(1,1) NOT NULL,
    app_name         NVARCHAR(100) NOT NULL,
    app_category     NVARCHAR(50)  NOT NULL,
    silver_loaded_at DATETIME2     NOT NULL CONSTRAINT df_silver_dim_app_loaded DEFAULT SYSDATETIME(),
    CONSTRAINT pk_silver_dim_app     PRIMARY KEY CLUSTERED (app_key),
    CONSTRAINT uq_silver_dim_app     UNIQUE (app_name)
);
GO

CREATE TABLE silver.dim_sleep_debt_category
(
    category_key     INT IDENTITY(1,1) NOT NULL,
    category_name    NVARCHAR(50)  NOT NULL,
    severity_rank    TINYINT       NOT NULL,   -- 1 = best sleep ... 4 = worst
    silver_loaded_at DATETIME2     NOT NULL CONSTRAINT df_silver_dim_cat_loaded DEFAULT SYSDATETIME(),
    CONSTRAINT pk_silver_dim_category PRIMARY KEY CLUSTERED (category_key),
    CONSTRAINT uq_silver_dim_category UNIQUE (category_name)
);
GO

-- ---------------------------------------------------------------------------
CREATE TABLE silver.fact_sleep_record
(
    sleep_record_key         INT IDENTITY(1,1) NOT NULL,
    user_key                 INT           NOT NULL,
    app_key                  INT           NOT NULL,
    category_key             INT           NOT NULL,
    -- measures
    bedtime_phone_minutes    INT           NOT NULL,
    screen_brightness_pct    INT           NOT NULL,
    blue_light_filter_active BIT           NOT NULL,
    caffeine_post_5pm_mg     INT           NOT NULL,
    physical_activity_min    INT           NOT NULL,
    sleep_latency_min        DECIMAL(6,1)  NOT NULL,
    total_sleep_hours        DECIMAL(4,2)  NOT NULL,
    deep_sleep_pct           DECIMAL(4,1)  NOT NULL,
    rem_sleep_pct            DECIMAL(4,1)  NOT NULL,
    morning_alarm_snoozes    INT           NOT NULL,
    next_day_fatigue_score   DECIMAL(3,1)  NOT NULL,
    -- enrichment / business rules
    screen_time_bucket       NVARCHAR(30)  NOT NULL,
    has_caffeine_flag        BIT           NOT NULL,
    deep_rem_total_pct       DECIMAL(5,1)  NOT NULL,
    high_fatigue_flag        BIT           NOT NULL,
    -- lineage
    source_bronze_id         INT           NOT NULL,
    silver_loaded_at         DATETIME2     NOT NULL CONSTRAINT df_silver_fact_loaded DEFAULT SYSDATETIME(),

    CONSTRAINT pk_silver_fact_sleep_record PRIMARY KEY CLUSTERED (sleep_record_key),
    CONSTRAINT uq_silver_fact_user         UNIQUE (user_key),
    CONSTRAINT fk_silver_fact_user         FOREIGN KEY (user_key)     REFERENCES silver.dim_user (user_key),
    CONSTRAINT fk_silver_fact_app          FOREIGN KEY (app_key)      REFERENCES silver.dim_app (app_key),
    CONSTRAINT fk_silver_fact_category     FOREIGN KEY (category_key) REFERENCES silver.dim_sleep_debt_category (category_key),
    CONSTRAINT ck_silver_fact_phone        CHECK (bedtime_phone_minutes BETWEEN 0 AND 1440),
    CONSTRAINT ck_silver_fact_brightness   CHECK (screen_brightness_pct BETWEEN 0 AND 100),
    CONSTRAINT ck_silver_fact_caffeine     CHECK (caffeine_post_5pm_mg >= 0),
    CONSTRAINT ck_silver_fact_activity     CHECK (physical_activity_min >= 0),
    CONSTRAINT ck_silver_fact_latency      CHECK (sleep_latency_min >= 0),
    CONSTRAINT ck_silver_fact_sleep_hours  CHECK (total_sleep_hours BETWEEN 0 AND 24),
    CONSTRAINT ck_silver_fact_deep         CHECK (deep_sleep_pct BETWEEN 0 AND 100),
    CONSTRAINT ck_silver_fact_rem          CHECK (rem_sleep_pct BETWEEN 0 AND 100),
    CONSTRAINT ck_silver_fact_deep_rem     CHECK (deep_sleep_pct + rem_sleep_pct <= 100),
    CONSTRAINT ck_silver_fact_snoozes      CHECK (morning_alarm_snoozes >= 0),
    CONSTRAINT ck_silver_fact_fatigue      CHECK (next_day_fatigue_score BETWEEN 1 AND 10)
);
GO

CREATE NONCLUSTERED INDEX ix_silver_fact_app      ON silver.fact_sleep_record (app_key);
CREATE NONCLUSTERED INDEX ix_silver_fact_category ON silver.fact_sleep_record (category_key);
GO
