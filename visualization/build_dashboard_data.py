"""
SleepDebtDW - Interactive Web Dashboard Builder
Generates data.js and dashboard.html for browser-based interactive exploration.
"""

import os
import json
import pandas as pd

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_PATH = os.path.join(BASE_DIR, '..', 'data', 'bedtime_screentime_sleep_debt_clean.csv')

df = pd.read_csv(DATA_PATH)

# Add derived columns matching Gold layer
def get_age_group(age):
    if age < 18: return 'Under 18'
    elif age <= 24: return '18-24'
    elif age <= 34: return '25-34'
    elif age <= 44: return '35-44'
    elif age <= 54: return '45-54'
    else: return '55+'
df['age_group'] = df['age'].apply(get_age_group)

def get_screen_bucket(m):
    if m < 30: return 'Low (<30 min)'
    elif m < 60: return 'Moderate (30-59 min)'
    elif m < 120: return 'High (60-119 min)'
    else: return 'Very High (120+ min)'
df['screen_time_bucket'] = df['bedtime_phone_minutes'].apply(get_screen_bucket)

app_cat_map = {
    'TikTok / Reels': 'Social Media',
    'Instagram / Reddit': 'Social Media',
    'YouTube': 'Video & Streaming',
    'Streaming (Netflix/Hulu)': 'Video & Streaming',
    'Messaging / Chat': 'Communication',
    'News / Reading': 'News & Reading'
}
df['app_category'] = df['primary_bedtime_app'].map(app_cat_map).fillna('Other')
df['has_caffeine_flag'] = (df['caffeine_post_5pm_mg'] > 0).astype(int)
df['high_fatigue_flag'] = (df['next_day_fatigue_score'] >= 7).astype(int)

# Export compact array representation for performance
columns = [
    'user_id', 'age', 'gender', 'occupation_type', 'chronotype',
    'bedtime_phone_minutes', 'primary_bedtime_app', 'app_category',
    'screen_brightness_pct', 'blue_light_filter_active', 'caffeine_post_5pm_mg',
    'has_caffeine_flag', 'physical_activity_min', 'sleep_latency_min',
    'total_sleep_hours', 'deep_sleep_pct', 'rem_sleep_pct',
    'morning_alarm_snoozes', 'next_day_fatigue_score', 'high_fatigue_flag',
    'sleep_debt_category', 'screen_time_bucket', 'age_group'
]

compact_rows = []
for row in df[columns].itertuples(index=False):
    compact_rows.append(list(row))

bundle = {
    'columns': columns,
    'total_count': len(compact_rows),
    'rows': compact_rows
}

# Write dashboard_data.js
js_content = f"window.SLEEP_DEBT_DATA = {json.dumps(bundle, separators=(',', ':'))};"
with open(os.path.join(BASE_DIR, 'dashboard_data.js'), 'w', encoding='utf-8') as f:
    f.write(js_content)

print(f">> Successfully built dashboard_data.js ({round(os.path.getsize(os.path.join(BASE_DIR, 'dashboard_data.js'))/1024, 1)} KB)")
