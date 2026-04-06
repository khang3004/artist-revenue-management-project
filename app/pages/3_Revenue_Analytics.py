import streamlit as st
import pandas as pd
import plotly.express as px
from utils.db import execute_query

st.title("💰 Revenue Analytics")

year = st.selectbox("Year", [2024, 2025, 2026], index=1)

# Revenue rollup
query = f"""
SELECT * FROM sp_revenue_by_artist_rollup({year}, 'VND')
"""

cols, rows = execute_query(query)
df = pd.DataFrame(rows, columns=cols)

st.subheader("Revenue by Artist & Month")

st.dataframe(df)

if not df.empty:
    df_chart = df[df["nghe_si"].notna()]
    fig = px.bar(df_chart, x="nghe_si", y="tong_doanhthu")
    st.plotly_chart(fig, use_container_width=True)

st.divider()

# Pivot revenue
st.subheader("Revenue by Source")

query = f"""
SELECT * FROM sp_revenue_pivot_by_source_v2({year})
"""

cols, rows = execute_query(query)
df = pd.DataFrame(rows, columns=cols)

st.dataframe(df)

if not df.empty:
    fig = px.bar(
        df, x="nghe_si", y=["streaming", "sync_rev", "live_rev"], barmode="stack"
    )
    st.plotly_chart(fig)

st.divider()

# Top tracks
st.subheader("Top Tracks per Artist")

query = f"""
SELECT * FROM sp_top_tracks_per_artist(3,{year})
"""

cols, rows = execute_query(query)
df = pd.DataFrame(rows, columns=cols)

st.dataframe(df)
