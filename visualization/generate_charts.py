"""
SleepDebtDW - Analytics & Visualization Generator
Generates publication-quality charts mirroring the Gold layer analytics queries.
"""

import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# Set overall aesthetic style
plt.style.use('seaborn-v0_8-whitegrid' if 'seaborn-v0_8-whitegrid' in plt.style.available else 'default')
plt.rcParams['font.sans-serif'] = ['DejaVu Sans', 'Arial', 'Helvetica', 'sans-serif']
plt.rcParams['axes.edgecolor'] = '#CBD5E1'
plt.rcParams['axes.linewidth'] = 0.8
plt.rcParams['grid.color'] = '#F1F5F9'
plt.rcParams['grid.linestyle'] = '--'

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'figures')
os.makedirs(OUTPUT_DIR, exist_ok=True)

CSV_PATH = os.path.join(os.path.dirname(__file__), '..', 'data', 'bedtime_screentime_sleep_debt_clean.csv')

def load_and_enrich_data():
    df = pd.read_csv(CSV_PATH)
    
    # Mirror Gold View derivations
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
    df['deep_rem_total_pct'] = df['deep_sleep_pct'] + df['rem_sleep_pct']
    
    return df

def chart_01_screen_time_impact(df):
    """Q3 & Q4: Bedtime Screen Time vs Sleep Duration, Latency, and Fatigue"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5.5), dpi=300)
    
    bucket_order = ['Low (<30 min)', 'Moderate (30-59 min)', 'High (60-119 min)', 'Very High (120+ min)']
    grouped = df.groupby('screen_time_bucket', observed=False).agg(
        avg_sleep=('total_sleep_hours', 'mean'),
        avg_latency=('sleep_latency_min', 'mean'),
        avg_fatigue=('next_day_fatigue_score', 'mean'),
        severe_debt_pct=('sleep_debt_category', lambda s: (s.isin(['Moderate Debt', 'Severe Sleep Debt'])).mean() * 100),
        count=('user_id', 'count')
    ).reindex(bucket_order)
    
    # Left: Sleep Duration vs Sleep Latency
    color_bar = '#3B82F6'
    color_line = '#EF4444'
    
    bars = ax1.bar(grouped.index, grouped['avg_sleep'], color=color_bar, alpha=0.85, width=0.45, label='Avg Sleep Hours')
    ax1.set_ylabel('Total Sleep (Hours)', color='#1E3A8A', fontsize=11, fontweight='bold')
    ax1.tick_params(axis='y', labelcolor='#1E3A8A')
    ax1.set_ylim(0, 9)
    ax1.set_title('Sleep Duration & Fall-Asleep Latency by Screen Time', fontsize=12, fontweight='bold', pad=12)
    ax1.set_xticks(range(len(grouped.index)))
    ax1.set_xticklabels(grouped.index, rotation=15, ha='right', fontsize=9.5)
    
    for bar in bars:
        height = bar.get_height()
        ax1.annotate(f'{height:.2f}h',
                     xy=(bar.get_x() + bar.get_width() / 2, height),
                     xytext=(0, 4), textcoords="offset points",
                     ha='center', va='bottom', fontsize=10, fontweight='bold', color='#1E3A8A')
                     
    ax1_twin = ax1.twinx()
    line = ax1_twin.plot(grouped.index, grouped['avg_latency'], color=color_line, marker='o', linewidth=2.5, markersize=8, label='Sleep Latency (min)')
    ax1_twin.set_ylabel('Sleep Latency (Minutes)', color='#991B1B', fontsize=11, fontweight='bold')
    ax1_twin.tick_params(axis='y', labelcolor='#991B1B')
    ax1_twin.set_ylim(0, 95)
    ax1_twin.grid(False)
    
    for i, val in enumerate(grouped['avg_latency']):
        ax1_twin.annotate(f'{val:.1f}m', xy=(i, val), xytext=(0, 7), textcoords="offset points",
                          ha='center', va='bottom', fontsize=10, fontweight='bold', color='#991B1B')
    
    # Right: Fatigue Score & Moderate/Severe Debt %
    bars2 = ax2.bar(grouped.index, grouped['avg_fatigue'], color='#F59E0B', alpha=0.85, width=0.45, label='Next-Day Fatigue Score (1-10)')
    ax2.set_ylabel('Avg Fatigue Score (1-10)', color='#B45309', fontsize=11, fontweight='bold')
    ax2.tick_params(axis='y', labelcolor='#B45309')
    ax2.set_ylim(0, 10.5)
    ax2.set_title('Next-Day Fatigue & Severe Sleep Debt Risk', fontsize=12, fontweight='bold', pad=12)
    ax2.set_xticks(range(len(grouped.index)))
    ax2.set_xticklabels(grouped.index, rotation=15, ha='right', fontsize=9.5)
    
    for bar in bars2:
        height = bar.get_height()
        ax2.annotate(f'{height:.2f}',
                     xy=(bar.get_x() + bar.get_width() / 2, height),
                     xytext=(0, 4), textcoords="offset points",
                     ha='center', va='bottom', fontsize=10, fontweight='bold', color='#B45309')
                     
    ax2_twin = ax2.twinx()
    line2 = ax2_twin.plot(grouped.index, grouped['severe_debt_pct'], color='#8B5CF6', marker='s', linewidth=2.5, markersize=8, label='% Mod/Severe Debt')
    ax2_twin.set_ylabel('% Moderate or Severe Debt', color='#5B21B6', fontsize=11, fontweight='bold')
    ax2_twin.tick_params(axis='y', labelcolor='#5B21B6')
    ax2_twin.set_ylim(0, 105)
    ax2_twin.grid(False)
    
    for i, val in enumerate(grouped['severe_debt_pct']):
        ax2_twin.annotate(f'{val:.1f}%', xy=(i, val), xytext=(0, 7), textcoords="offset points",
                          ha='center', va='bottom', fontsize=10, fontweight='bold', color='#5B21B6')
                          
    plt.tight_layout()
    fig.savefig(os.path.join(OUTPUT_DIR, '01_screen_time_vs_sleep_metrics.png'), dpi=300)
    plt.close()

def chart_02_sleep_debt_distribution(df):
    """Q2: Sleep Debt Category Distribution and Sleep Duration"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 5.5), dpi=300)
    
    category_order = ['Optimal Recovery', 'Mild Deficit', 'Moderate Debt', 'Severe Sleep Debt']
    palette = ['#10B981', '#3B82F6', '#F59E0B', '#EF4444']
    
    counts = df['sleep_debt_category'].value_counts().reindex(category_order)
    percentages = (counts / counts.sum()) * 100
    
    wedges, texts, autotexts = ax1.pie(
        counts,
        labels=category_order,
        autopct='%1.1f%%',
        startangle=140,
        colors=palette,
        pctdistance=0.75,
        explode=(0.04, 0.02, 0.02, 0.08),
        wedgeprops=dict(width=0.45, edgecolor='white', linewidth=2)
    )
    for at in autotexts:
        at.set_color('white')
        at.set_weight('bold')
        at.set_fontsize(10)
    for t in texts:
        t.set_fontsize(10)
        t.set_weight('bold')
        
    ax1.set_title(f'Sleep Debt Classification\n(Total Users = {len(df):,})', fontsize=12, fontweight='bold')
    
    # Bar chart of avg sleep hours per category
    avg_hours = df.groupby('sleep_debt_category', observed=False)['total_sleep_hours'].mean().reindex(category_order)
    avg_latency = df.groupby('sleep_debt_category', observed=False)['sleep_latency_min'].mean().reindex(category_order)
    
    bars = ax2.barh(category_order, avg_hours, color=palette, alpha=0.9, height=0.55)
    ax2.set_xlabel('Average Total Sleep (Hours)', fontsize=11, fontweight='bold', labelpad=8)
    ax2.set_title('Average Sleep Duration by Severity Category', fontsize=12, fontweight='bold', pad=12)
    ax2.set_xlim(0, 9)
    ax2.invert_yaxis()
    
    for bar, hours, lat in zip(bars, avg_hours, avg_latency):
        ax2.text(hours + 0.15, bar.get_y() + bar.get_height()/2,
                 f'{hours:.2f} hrs  (Latency: {lat:.1f}m)',
                 va='center', fontsize=9.5, fontweight='bold', color='#1E293B')
                 
    plt.tight_layout()
    fig.savefig(os.path.join(OUTPUT_DIR, '02_sleep_debt_distribution.png'), dpi=300)
    plt.close()

def chart_03_bedtime_apps_impact(df):
    """Q6: Which Bedtime Apps are Linked to the Worst Sleep?"""
    fig, ax = plt.subplots(figsize=(11, 6), dpi=300)
    
    app_metrics = df.groupby('primary_bedtime_app', observed=False).agg(
        avg_sleep=('total_sleep_hours', 'mean'),
        avg_phone_min=('bedtime_phone_minutes', 'mean'),
        avg_fatigue=('next_day_fatigue_score', 'mean'),
        user_count=('user_id', 'count'),
        app_category=('app_category', 'first')
    ).sort_values('avg_sleep', ascending=True)
    
    y_pos = np.arange(len(app_metrics))
    # Category color map
    cat_colors = {
        'Social Media': '#EF4444',
        'Video & Streaming': '#F59E0B',
        'Communication': '#3B82F6',
        'News & Reading': '#10B981'
    }
    colors = [cat_colors.get(cat, '#64748B') for cat in app_metrics['app_category']]
    
    bars = ax.barh(y_pos, app_metrics['avg_sleep'], color=colors, alpha=0.88, height=0.55)
    ax.set_yticks(y_pos)
    ax.set_yticklabels(app_metrics.index, fontsize=10, fontweight='bold')
    ax.set_xlabel('Average Total Sleep Hours', fontsize=11, fontweight='bold', labelpad=8)
    ax.set_xlim(0, 8.5)
    ax.set_title('Bedtime App Impact on Sleep Duration & Next-Day Fatigue', fontsize=13, fontweight='bold', pad=14)
    
    # Annotate details: sleep hours, fatigue score, app category
    for i, (idx, row) in enumerate(app_metrics.iterrows()):
        ax.text(row['avg_sleep'] + 0.1, i,
                f"{row['avg_sleep']:.2f} hrs  |  Fatigue: {row['avg_fatigue']:.2f}/10  |  Screen: {row['avg_phone_min']:.0f}m  (n={row['user_count']})",
                va='center', fontsize=9, fontweight='bold', color='#1E293B')
                
    # Legend for categories
    handles = [plt.Rectangle((0,0),1,1, color=col) for col in cat_colors.values()]
    ax.legend(handles, cat_colors.keys(), title='App Category', loc='lower right', frameon=True, fontsize=9.5)
    
    plt.tight_layout()
    fig.savefig(os.path.join(OUTPUT_DIR, '03_bedtime_apps_impact.png'), dpi=300)
    plt.close()

def chart_04_chronotype_and_occupation(df):
    """Q7: Chronotype x Occupation: Sleep Hours & Snooze Count"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6), dpi=300)
    
    pivot_sleep = df.pivot_table(index='occupation_type', columns='chronotype', values='total_sleep_hours', aggfunc='mean')
    pivot_snooze = df.pivot_table(index='occupation_type', columns='chronotype', values='morning_alarm_snoozes', aggfunc='mean')
    
    # Custom sort by overall average
    order = df.groupby('occupation_type')['total_sleep_hours'].mean().sort_values().index
    pivot_sleep = pivot_sleep.reindex(order)
    pivot_snooze = pivot_snooze.reindex(order)
    
    # Heatmap 1: Sleep Hours
    sns.heatmap(pivot_sleep, annot=True, fmt=".2f", cmap="Blues_r", cbar_kws={'label': 'Avg Sleep (Hours)'},
                ax=ax1, linewidths=1.2, linecolor='white')
    ax1.set_title('Average Sleep Duration (Hours)\nOccupation vs Chronotype', fontsize=12, fontweight='bold', pad=12)
    ax1.set_xlabel('Chronotype', fontsize=10, fontweight='bold')
    ax1.set_ylabel('Occupation Type', fontsize=10, fontweight='bold')
    
    # Heatmap 2: Morning Alarm Snoozes
    sns.heatmap(pivot_snooze, annot=True, fmt=".2f", cmap="Oranges", cbar_kws={'label': 'Avg Alarm Snoozes'},
                ax=ax2, linewidths=1.2, linecolor='white')
    ax2.set_title('Average Morning Alarm Snoozes\nOccupation vs Chronotype', fontsize=12, fontweight='bold', pad=12)
    ax2.set_xlabel('Chronotype', fontsize=10, fontweight='bold')
    ax2.set_ylabel('')
    
    plt.tight_layout()
    fig.savefig(os.path.join(OUTPUT_DIR, '04_chronotype_and_occupation.png'), dpi=300)
    plt.close()

def chart_05_blue_light_and_caffeine(df):
    """Q5 & Q8: Blue Light Filter & Late Caffeine Impact"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 5.5), dpi=300)
    
    # Blue Light Filter
    bl_grp = df.groupby('blue_light_filter_active').agg(
        latency=('sleep_latency_min', 'mean'),
        sleep=('total_sleep_hours', 'mean'),
        deep=('deep_sleep_pct', 'mean'),
        count=('user_id', 'count')
    )
    bl_labels = ['Filter OFF', 'Filter ON']
    
    x = np.arange(len(bl_labels))
    width = 0.35
    
    bars_bl1 = ax1.bar(x - width/2, bl_grp['latency'], width, label='Sleep Latency (min)', color='#EF4444', alpha=0.85)
    bars_bl2 = ax1.bar(x + width/2, bl_grp['deep'], width, label='Deep Sleep %', color='#3B82F6', alpha=0.85)
    
    ax1.set_xticks(x)
    ax1.set_xticklabels(bl_labels, fontsize=10, fontweight='bold')
    ax1.set_ylabel('Minutes / Percentage', fontsize=10, fontweight='bold')
    ax1.set_title('Blue Light Filter Efficacy\n(Sleep Latency & Deep Sleep %)', fontsize=12, fontweight='bold', pad=12)
    ax1.legend(loc='upper right')
    ax1.set_ylim(0, 55)
    
    for bar in bars_bl1:
        h = bar.get_height()
        ax1.annotate(f'{h:.1f}m', xy=(bar.get_x() + bar.get_width()/2, h), xytext=(0, 3),
                     textcoords="offset points", ha='center', fontsize=9.5, fontweight='bold', color='#991B1B')
    for bar in bars_bl2:
        h = bar.get_height()
        ax1.annotate(f'{h:.1f}%', xy=(bar.get_x() + bar.get_width()/2, h), xytext=(0, 3),
                     textcoords="offset points", ha='center', fontsize=9.5, fontweight='bold', color='#1E3A8A')
                     
    # Late Caffeine Impact
    caf_grp = df.groupby('has_caffeine_flag').agg(
        latency=('sleep_latency_min', 'mean'),
        sleep=('total_sleep_hours', 'mean'),
        deep=('deep_sleep_pct', 'mean'),
        fatigue=('next_day_fatigue_score', 'mean'),
        count=('user_id', 'count')
    )
    caf_labels = ['No Late Caffeine', 'Caffeine Post-5PM']
    
    bars_caf1 = ax2.bar(x - width/2, caf_grp['latency'], width, label='Sleep Latency (min)', color='#F59E0B', alpha=0.85)
    bars_caf2 = ax2.bar(x + width/2, caf_grp['deep'], width, label='Deep Sleep %', color='#8B5CF6', alpha=0.85)
    
    ax2.set_xticks(x)
    ax2.set_xticklabels(caf_labels, fontsize=10, fontweight='bold')
    ax2.set_ylabel('Minutes / Percentage', fontsize=10, fontweight='bold')
    ax2.set_title('Late Caffeine Impact (>0 mg Post-5PM)\n(Sleep Latency & Deep Sleep %)', fontsize=12, fontweight='bold', pad=12)
    ax2.legend(loc='upper right')
    ax2.set_ylim(0, 55)
    
    for bar in bars_caf1:
        h = bar.get_height()
        ax2.annotate(f'{h:.1f}m', xy=(bar.get_x() + bar.get_width()/2, h), xytext=(0, 3),
                     textcoords="offset points", ha='center', fontsize=9.5, fontweight='bold', color='#B45309')
    for bar in bars_caf2:
        h = bar.get_height()
        ax2.annotate(f'{h:.1f}%', xy=(bar.get_x() + bar.get_width()/2, h), xytext=(0, 3),
                     textcoords="offset points", ha='center', fontsize=9.5, fontweight='bold', color='#5B21B6')
                     
    plt.tight_layout()
    fig.savefig(os.path.join(OUTPUT_DIR, '05_blue_light_and_caffeine_effects.png'), dpi=300)
    plt.close()

def chart_06_correlation_matrix(df):
    """Full Numeric Correlation Heatmap"""
    cols = [
        'bedtime_phone_minutes', 'sleep_latency_min', 'total_sleep_hours',
        'deep_sleep_pct', 'rem_sleep_pct', 'morning_alarm_snoozes',
        'next_day_fatigue_score', 'caffeine_post_5pm_mg', 'screen_brightness_pct',
        'physical_activity_min', 'age'
    ]
    labels = [
        'Phone Mins', 'Sleep Latency', 'Sleep Hours',
        'Deep Sleep %', 'REM Sleep %', 'Alarm Snoozes',
        'Fatigue Score', 'Caffeine Post-5pm', 'Brightness %',
        'Activity Mins', 'Age'
    ]
    
    corr = df[cols].corr()
    corr.columns = labels
    corr.index = labels
    
    fig, ax = plt.subplots(figsize=(10, 8.5), dpi=300)
    mask = np.triu(np.ones_like(corr, dtype=bool))
    
    sns.heatmap(corr, mask=mask, annot=True, fmt=".2f", cmap='coolwarm', vmin=-1, vmax=1,
                linewidths=0.8, linecolor='white', cbar_kws={'label': 'Pearson Correlation (r)'}, ax=ax)
    
    ax.set_title('Correlation Heatmap: Sleep Architecture & Behavioral Factors', fontsize=13, fontweight='bold', pad=15)
    plt.tight_layout()
    fig.savefig(os.path.join(OUTPUT_DIR, '06_correlation_matrix.png'), dpi=300)
    plt.close()

def chart_07_activity_and_age_profile(df):
    """Q9 & Q10: Age Group Profile & Physical Activity Quartiles"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5.5), dpi=300)
    
    # Q9: Age group profile
    age_order = ['18-24', '25-34', '35-44', '45-54', '55+']
    age_grp = df.groupby('age_group').agg(
        avg_sleep=('total_sleep_hours', 'mean'),
        avg_phone=('bedtime_phone_minutes', 'mean'),
        high_fatigue_pct=('high_fatigue_flag', lambda s: s.mean() * 100)
    ).reindex(age_order)
    
    bars1 = ax1.bar(age_grp.index, age_grp['avg_phone'], color='#6366F1', alpha=0.85, width=0.45, label='Bedtime Phone Min')
    ax1.set_ylabel('Bedtime Phone (Minutes)', color='#3730A3', fontsize=10, fontweight='bold')
    ax1.set_ylim(0, 80)
    ax1.set_title('Age Group vs Screen Time & High Fatigue Rate', fontsize=12, fontweight='bold', pad=12)
    
    for bar in bars1:
        h = bar.get_height()
        ax1.annotate(f'{h:.1f}m', xy=(bar.get_x() + bar.get_width()/2, h), xytext=(0, 3),
                     textcoords="offset points", ha='center', fontsize=9.5, fontweight='bold', color='#3730A3')
                     
    ax1_twin = ax1.twinx()
    line1 = ax1_twin.plot(age_grp.index, age_grp['high_fatigue_pct'], color='#EF4444', marker='o', linewidth=2.5, markersize=8)
    ax1_twin.set_ylabel('% High Fatigue (Score >= 7)', color='#991B1B', fontsize=10, fontweight='bold')
    ax1_twin.set_ylim(0, 40)
    ax1_twin.grid(False)
    
    for i, val in enumerate(age_grp['high_fatigue_pct']):
        ax1_twin.annotate(f'{val:.1f}%', xy=(i, val), xytext=(0, 6), textcoords="offset points",
                          ha='center', fontsize=9.5, fontweight='bold', color='#991B1B')
                          
    # Q10: Physical activity quartiles
    df['activity_quartile'] = pd.qcut(df['physical_activity_min'], q=4, labels=['Q1 (Low)', 'Q2 (Mid-Low)', 'Q3 (Mid-High)', 'Q4 (High)'])
    act_grp = df.groupby('activity_quartile', observed=False).agg(
        min_act=('physical_activity_min', 'min'),
        max_act=('physical_activity_min', 'max'),
        avg_sleep=('total_sleep_hours', 'mean'),
        avg_latency=('sleep_latency_min', 'mean')
    )
    
    x = np.arange(len(act_grp))
    width = 0.35
    bars_act1 = ax2.bar(x - width/2, act_grp['avg_sleep'], width, label='Sleep Duration (hrs)', color='#10B981', alpha=0.85)
    ax2.set_ylabel('Total Sleep (Hours)', color='#065F46', fontsize=10, fontweight='bold')
    ax2.set_ylim(0, 9)
    ax2.set_xticks(x)
    labels = [f"{idx}\n({row['min_act']}-{row['max_act']}m)" for idx, row in act_grp.iterrows()]
    ax2.set_xticklabels(labels, fontsize=9.5, fontweight='bold')
    ax2.set_title('Physical Activity Quartiles vs Sleep Duration & Latency', fontsize=12, fontweight='bold', pad=12)
    
    for bar in bars_act1:
        h = bar.get_height()
        ax2.annotate(f'{h:.2f}h', xy=(bar.get_x() + bar.get_width()/2, h), xytext=(0, 3),
                     textcoords="offset points", ha='center', fontsize=9, fontweight='bold', color='#065F46')
                     
    ax2_twin = ax2.twinx()
    line_act2 = ax2_twin.plot(x + width/2, act_grp['avg_latency'], color='#F59E0B', marker='s', linewidth=2.5, markersize=8)
    ax2_twin.set_ylabel('Sleep Latency (Minutes)', color='#B45309', fontsize=10, fontweight='bold')
    ax2_twin.set_ylim(0, 50)
    ax2_twin.grid(False)
    
    for i, val in enumerate(act_grp['avg_latency']):
        ax2_twin.annotate(f'{val:.1f}m', xy=(i + width/2, val), xytext=(0, 6), textcoords="offset points",
                          ha='center', fontsize=9, fontweight='bold', color='#B45309')
                          
    plt.tight_layout()
    fig.savefig(os.path.join(OUTPUT_DIR, '07_physical_activity_and_age_profiles.png'), dpi=300)
    plt.close()

def chart_00_executive_dashboard_summary(df):
    """All-in-one Executive Summary Infographic Dashboard"""
    fig = plt.figure(figsize=(18, 12), dpi=300)
    gs = fig.add_gridspec(3, 3, hspace=0.35, wspace=0.28)
    
    # Title Banner area
    fig.suptitle('SleepDebtDW - Executive Sleep & Screen Time Analytics Dashboard',
                 fontsize=18, fontweight='bold', y=0.98, color='#0F172A')
                 
    # 1. KPI Panel (Top Left)
    ax_kpi = fig.add_subplot(gs[0, 0])
    ax_kpi.axis('off')
    kpis = [
        ("Total Study Population", f"{len(df):,} Users"),
        ("Avg Sleep Duration", f"{df['total_sleep_hours'].mean():.2f} hrs"),
        ("Avg Bedtime Phone Time", f"{df['bedtime_phone_minutes'].mean():.1f} mins"),
        ("Avg Sleep Latency", f"{df['sleep_latency_min'].mean():.1f} mins"),
        ("Avg Fatigue Score (1-10)", f"{df['next_day_fatigue_score'].mean():.2f} / 10"),
        ("High Fatigue Rate (>=7)", f"{(df['high_fatigue_flag'].mean()*100):.1f}% of cohort"),
    ]
    ax_kpi.set_title("Core Cohort KPIs", fontsize=13, fontweight='bold', color='#1E293B', pad=10)
    
    y_step = 0.82 / len(kpis)
    for i, (title, val) in enumerate(kpis):
        y = 0.88 - i * y_step
        ax_kpi.text(0.04, y, title, fontsize=10, color='#64748B', fontweight='bold')
        ax_kpi.text(0.96, y, val, fontsize=11, color='#1E3A8A', fontweight='bold', ha='right')
        ax_kpi.axhline(y - 0.035, 0.04, 0.96, color='#E2E8F0', linewidth=1)
        
    # 2. Sleep Debt Category Donut (Top Center)
    ax_pie = fig.add_subplot(gs[0, 1])
    category_order = ['Optimal Recovery', 'Mild Deficit', 'Moderate Debt', 'Severe Sleep Debt']
    counts = df['sleep_debt_category'].value_counts().reindex(category_order)
    colors_debt = ['#10B981', '#3B82F6', '#F59E0B', '#EF4444']
    ax_pie.pie(counts, labels=category_order, autopct='%1.1f%%', colors=colors_debt, startangle=140,
               wedgeprops=dict(width=0.45, edgecolor='white', linewidth=2),
               textprops=dict(fontsize=8.5, weight='bold'))
    ax_pie.set_title("Sleep Debt Distribution", fontsize=12, fontweight='bold')

    # 3. Screen Time Buckets vs Sleep Duration (Top Right)
    ax_bucket = fig.add_subplot(gs[0, 2])
    bucket_order = ['Low (<30m)', 'Mod (30-59m)', 'High (60-119m)', 'V.High (120m+)']
    grouped = df.groupby('screen_time_bucket', observed=False)['total_sleep_hours'].mean().values
    bars = ax_bucket.bar(bucket_order, grouped, color=['#10B981', '#3B82F6', '#F59E0B', '#EF4444'], width=0.5)
    ax_bucket.set_ylim(0, 8.5)
    ax_bucket.set_ylabel('Avg Sleep (Hours)', fontsize=9.5, fontweight='bold')
    ax_bucket.set_title('Screen Time vs Sleep Hours', fontsize=12, fontweight='bold')
    ax_bucket.tick_params(axis='x', rotation=15, labelsize=8.5)
    for b in bars:
        h = b.get_height()
        ax_bucket.annotate(f'{h:.2f}h', (b.get_x() + b.get_width()/2, h), xytext=(0, 2),
                           textcoords="offset points", ha='center', fontsize=9, fontweight='bold')

    # 4. App Impact on Fatigue & Sleep (Middle Left & Center spanned)
    ax_app = fig.add_subplot(gs[1, 0:2])
    app_metrics = df.groupby('primary_bedtime_app', observed=False).agg(
        avg_sleep=('total_sleep_hours', 'mean'),
        avg_fatigue=('next_day_fatigue_score', 'mean')
    ).sort_values('avg_sleep', ascending=True)
    
    y = np.arange(len(app_metrics))
    bars = ax_app.barh(y, app_metrics['avg_sleep'], color='#6366F1', alpha=0.85, height=0.5)
    ax_app.set_yticks(y)
    ax_app.set_yticklabels(app_metrics.index, fontsize=9.5, fontweight='bold')
    ax_app.set_xlim(0, 8)
    ax_app.set_xlabel('Sleep Hours', fontsize=9.5, fontweight='bold')
    ax_app.set_title('Bedtime Apps: Sleep Duration vs Next-Day Fatigue Score', fontsize=12, fontweight='bold')
    for i, (idx, row) in enumerate(app_metrics.iterrows()):
        ax_app.text(row['avg_sleep'] + 0.1, i, f"{row['avg_sleep']:.2f}h (Fatigue: {row['avg_fatigue']:.2f}/10)",
                    va='center', fontsize=8.5, fontweight='bold', color='#1E293B')

    # 5. Blue Light Filter Effect (Middle Right)
    ax_bl = fig.add_subplot(gs[1, 2])
    bl_data = df.groupby('blue_light_filter_active')[['sleep_latency_min', 'deep_sleep_pct']].mean()
    x = np.arange(2)
    ax_bl.bar(x - 0.15, bl_data['sleep_latency_min'], width=0.3, label='Latency (min)', color='#EF4444', alpha=0.85)
    ax_bl.bar(x + 0.15, bl_data['deep_sleep_pct'], width=0.3, label='Deep Sleep %', color='#3B82F6', alpha=0.85)
    ax_bl.set_xticks(x)
    ax_bl.set_xticklabels(['Filter OFF', 'Filter ON'], fontsize=9.5, fontweight='bold')
    ax_bl.set_title('Blue Light Filter Efficacy', fontsize=12, fontweight='bold')
    ax_bl.legend(fontsize=8, loc='upper right')

    # 6. Chronotype x Occupation Heatmap (Bottom Left & Center spanned)
    ax_hm = fig.add_subplot(gs[2, 0:2])
    pivot_sleep = df.pivot_table(index='occupation_type', columns='chronotype', values='total_sleep_hours', aggfunc='mean')
    sns.heatmap(pivot_sleep, annot=True, fmt=".2f", cmap="Blues_r", ax=ax_hm, cbar_kws={'label': 'Sleep (hrs)'},
                linewidths=0.8, linecolor='white')
    ax_hm.set_title('Sleep Duration by Occupation & Chronotype', fontsize=12, fontweight='bold')
    ax_hm.set_xlabel('Chronotype', fontsize=9.5, fontweight='bold')
    ax_hm.set_ylabel('Occupation Type', fontsize=9.5, fontweight='bold')

    # 7. Correlation Snapshot (Bottom Right)
    ax_corr = fig.add_subplot(gs[2, 2])
    core_corr = df[['bedtime_phone_minutes', 'sleep_latency_min', 'total_sleep_hours', 'next_day_fatigue_score']].corr()
    core_corr.columns = ['Phone', 'Latency', 'Sleep', 'Fatigue']
    core_corr.index = ['Phone', 'Latency', 'Sleep', 'Fatigue']
    sns.heatmap(core_corr, annot=True, fmt=".2f", cmap='coolwarm', vmin=-1, vmax=1, ax=ax_corr,
                linewidths=0.8, linecolor='white', cbar=False)
    ax_corr.set_title('Core Drivers Correlation', fontsize=12, fontweight='bold')

    fig.savefig(os.path.join(OUTPUT_DIR, '00_executive_dashboard_summary.png'), dpi=300)
    plt.close()

def main():
    print(">> Loading and enriching sleep debt dataset...")
    df = load_and_enrich_data()
    print(f">> Loaded {len(df):,} records successfully.")
    
    print(">> Generating Chart 01: Screen time impact on sleep metrics...")
    chart_01_screen_time_impact(df)
    
    print(">> Generating Chart 02: Sleep debt category distribution...")
    chart_02_sleep_debt_distribution(df)
    
    print(">> Generating Chart 03: Bedtime apps ranking & fatigue impact...")
    chart_03_bedtime_apps_impact(df)
    
    print(">> Generating Chart 04: Chronotype x Occupation heatmaps...")
    chart_04_chronotype_and_occupation(df)
    
    print(">> Generating Chart 05: Blue light filter & late caffeine effects...")
    chart_05_blue_light_and_caffeine(df)
    
    print(">> Generating Chart 06: Full correlation matrix...")
    chart_06_correlation_matrix(df)
    
    print(">> Generating Chart 07: Age profiles & physical activity quartiles...")
    chart_07_activity_and_age_profile(df)
    
    print(">> Generating Chart 00: Master executive dashboard infographic...")
    chart_00_executive_dashboard_summary(df)
    
    print(f">> All figures successfully generated and saved to: {OUTPUT_DIR}")

if __name__ == '__main__':
    main()
