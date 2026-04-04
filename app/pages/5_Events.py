import streamlit as st
import pandas as pd
import plotly.express as px
from utils.db import execute_query

st.title("🎤 Events & Venues")

year = st.selectbox("Year", [2024, 2025, 2026], index=1)

query = f"""
SELECT * FROM sp_venue_event_analytics({year})
"""

cols, rows = execute_query(query)
df = pd.DataFrame(rows, columns=cols)

st.dataframe(df)

if not df.empty:
    df_chart = df[df["venue_name"].notna()]
    fig = px.bar(
        df_chart,
        x="venue_name",
        y="doanh_thu_live"
    )
    st.plotly_chart(fig, use_container_width=True)