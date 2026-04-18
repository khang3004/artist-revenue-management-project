"""
Artist Revenue Management System — Dashboard (Page 1)
MDL018 — HCMUS
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import os
from utils.db import get_db_connection, test_connection, run_query

st.set_page_config(
    page_title="V-POP Artist Revenue",
    page_icon="🎵",
    layout="wide",
    initial_sidebar_state="expanded",
)

# Load CSS
css_file = os.path.join(os.path.dirname(__file__), "assets", "style.css")
if os.path.exists(css_file):
    with open(css_file) as f:
        st.markdown(f"<style>{f.read()}</style>", unsafe_allow_html=True)

# Warm up Neon
with st.spinner("Dang ket noi Neon DB..."):
    connected = test_connection()

# --- Header ---
st.title("🎵 Artist Revenue Management System")
st.caption("MDL018 — To chuc va Quan ly Du lieu | HCMUS")
st.divider()

if not connected:
    st.error("Khong the ket noi database. Kiem tra DATABASE_URL trong .env")
    st.stop()

# --- KPI Metrics ---
kpi_queries = {
    "🎤 Artists": "SELECT COUNT(*) FROM artists",
    "🎵 Tracks": "SELECT COUNT(*) FROM tracks",
    "📝 Contracts": "SELECT COUNT(*) FROM contracts WHERE status = 'active'",
    "💰 Revenue Logs": "SELECT COUNT(*) FROM revenue_logs",
    "👛 Wallets": "SELECT COUNT(*) FROM artist_wallets",
    "🎪 Events": "SELECT COUNT(*) FROM events",
}

cols = st.columns(len(kpi_queries))
for col, (label, q) in zip(cols, kpi_queries.items()):
    df, _, err = run_query(q)
    val = df.iloc[0, 0] if df is not None and not df.empty else 0
    col.metric(label, f"{val:,}")

st.divider()

# --- Year selector ---
year = st.selectbox("Nam", [2024, 2025, 2026], index=1, key="dash_year")

# --- Charts row ---
c1, c2 = st.columns(2)

# Revenue by month (line chart)
with c1:
    st.subheader("📈 Doanh thu theo thang")
    df, ms, err = run_query(f"""
        SELECT TO_CHAR(log_date, 'YYYY-MM') AS thang,
               SUM(amount) AS doanh_thu
        FROM revenue_logs
        WHERE EXTRACT(YEAR FROM log_date) = {year}
        GROUP BY thang ORDER BY thang
    """)
    if df is not None and not df.empty:
        fig = px.line(
            df,
            x="thang",
            y="doanh_thu",
            markers=True,
            labels={"thang": "Thang", "doanh_thu": "Doanh thu (VND)"},
        )
        fig.update_layout(height=350)
        st.plotly_chart(fig, use_container_width=True)
        st.caption(f"⏱️ {ms}ms")
    else:
        st.info("Chua co du lieu.")

# Top 5 artists (bar chart)
with c2:
    st.subheader("🏆 Top 5 nghe si")
    df, ms, err = run_query(f"""
        SELECT a.stage_name AS nghe_si, SUM(r.amount) AS doanh_thu
        FROM revenue_logs r
        JOIN tracks t ON r.track_id = t.track_id
        JOIN albums al ON t.album_id = al.album_id
        JOIN artists a ON al.artist_id = a.artist_id
        WHERE EXTRACT(YEAR FROM r.log_date) = {year}
        GROUP BY a.stage_name
        ORDER BY doanh_thu DESC LIMIT 5
    """)
    if df is not None and not df.empty:
        fig = px.bar(
            df,
            x="nghe_si",
            y="doanh_thu",
            text_auto=True,
            labels={"nghe_si": "Nghe si", "doanh_thu": "Doanh thu (VND)"},
            color_discrete_sequence=["#1E2761"],
        )
        fig.update_layout(height=350)
        st.plotly_chart(fig, use_container_width=True)
        st.caption(f"⏱️ {ms}ms")
    else:
        st.info("Chua co du lieu.")

# Revenue by source (pie chart)
st.subheader("🎯 Doanh thu theo nguon")
df, ms, err = run_query(f"SELECT * FROM sp_revenue_pivot_by_source_v2({year})")
if df is not None and not df.empty:
    totals = {
        "Streaming": df["streaming"].sum(),
        "Sync": df["sync_rev"].sum(),
        "Live": df["live_rev"].sum(),
    }
    totals = {k: v for k, v in totals.items() if v and v > 0}
    if totals:
        fig = px.pie(
            names=list(totals.keys()),
            values=list(totals.values()),
            color_discrete_sequence=["#1E2761", "#F96167", "#CADCFC"],
        )
        fig.update_layout(height=350)
        st.plotly_chart(fig, use_container_width=True)
        st.caption(f"⏱️ {ms}ms")
else:
    st.info("Chua co du lieu.")

st.divider()
st.caption("Neon Serverless PostgreSQL 16 | Streamlit + Plotly | 14 Stored Procedures")
