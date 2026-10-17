# SleepDebtDW - Medallion Data Warehouse (SQL Server)

Source: `bedtime_screentime_sleep_debt.csv` (8,500 users x 18 columns)

## Run order
1. **Python cleaning**: open `python_cleaning/clean_sleep_data.ipynb` in Jupyter and run all cells
   (needs `pandas`) -> writes `data/bedtime_screentime_sleep_debt_clean.csv` + a small quality log CSV
2. `00_init_database.sql`  - drops/re-creates `SleepDebtDW`, creates the 4 schemas
3. `01_staging/01_ddl_staging.sql`, then `02_sp_load_staging.sql`
4. `02_bronze/01_ddl_bronze.sql`,  then `02_sp_load_bronze.sql`
5. `03_silver/01_ddl_silver.sql`,  then `02_sp_load_silver.sql`
6. `04_gold/04_gold_views.sql`
7. Load data (run in SSMS):
   ```sql
   EXEC staging.load_staging @file_path = N'C:\SleepDebtDW\data\bedtime_screentime_sleep_debt_clean.csv';
   EXEC bronze.load_bronze;
   EXEC silver.load_silver;
   ```
8. `05_analytics_queries.sql` - business questions on the Gold views

## Requirements / notes
- SQL Server 2017+ (`BULK INSERT ... FORMAT = 'CSV'`). The CSV path is read by the SQL Server *service*, so
  copy the file to a folder the server can access.
- Re-running steps 7 is safe: Bronze only updates changed users / inserts new ones; Silver rebuilds the fact.
- Grain: one row per user (the source has no date column), so there is no date dimension.
