import streamlit as st
import pandas as pd
import plotly.express as px
from utils.db import execute_query
from utils.ui import apply_apple_style

st.set_page_config(page_title="Events & Venues", layout="wide")
apply_apple_style()

st.title("🎤 Events & Venues")

with st.container(border=True):
    year = st.selectbox("Year", [2024, 2025, 2026], index=1)

    query = f"""
    SELECT * FROM sp_venue_event_analytics({year}::INTEGER)
    """

    cols, rows = execute_query(query)
    df = pd.DataFrame(rows, columns=cols)

    if not df.empty:
        st.dataframe(df, use_container_width=True)

        df_chart = df[df["venue_name"].notna()]
        if not df_chart.empty:
            fig = px.bar(
                df_chart, 
                x="venue_name", 
                y="doanh_thu_live",
                title="Revenue by Venue",
                template="plotly_dark",
                color="doanh_thu_live",
                color_continuous_scale="Viridis"
            )
            fig.update_layout(
                plot_bgcolor='rgba(0,0,0,0)',
                paper_bgcolor='rgba(0,0,0,0)',
            )
            st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No event data available for this year.")

