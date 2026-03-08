import streamlit as st
import pandas as pd
import plotly.express as px
from utils.db import execute_query

st.title("🎤 Events & Venues")

year = st.selectbox("Year", [2022, 2023, 2024], index=2)

query = f"""
SELECT * FROM sp_venue_event_analytics({year})
"""

cols, rows = execute_query(query)
df = pd.DataFrame(rows, columns=cols)

st.dataframe(df)

if not df.empty:
    fig = px.bar(
        df,
        x="venue_name",
        y="doanh_thu_live"
    )
    st.plotly_chart(fig)