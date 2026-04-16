import streamlit as st
import pandas as pd
import plotly.express as px
from utils.db import execute_query
from utils.ui import apply_apple_style

st.set_page_config(page_title="Revenue Analytics", layout="wide")
apply_apple_style()

st.title("💰 Revenue Analytics")

with st.container(border=True):
    year = st.selectbox("Year", [2024, 2025, 2026], index=1)

# Revenue rollup
st.subheader("Revenue by Artist & Month")
with st.container(border=True):
    query = f"""
    SELECT * FROM sp_revenue_by_artist_rollup({year}::INTEGER, 'VND'::VARCHAR)
    """

    cols, rows = execute_query(query)
    df = pd.DataFrame(rows, columns=cols)

    if not df.empty:
        st.dataframe(df, use_container_width=True)
        
        df_chart = df[df["nghe_si"].notna() & (df["nghe_si"] != '★ TỔNG CỘNG ★')]
        if not df_chart.empty:
            fig = px.bar(
                df_chart, 
                x="nghe_si", 
                y="tong_doanhthu", 
                color="thang",
                title="Revenue Distribution by Artist",
                template="plotly_dark"
            )
            fig.update_layout(
                plot_bgcolor='rgba(0,0,0,0)',
                paper_bgcolor='rgba(0,0,0,0)',
            )
            st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No rollup data available.")

# Pivot revenue
st.subheader("Revenue by Source")
with st.container(border=True):
    query = f"""
    SELECT * FROM sp_revenue_pivot_by_source_v2({year}::INTEGER)
    """

    cols, rows = execute_query(query)
    df_pivot = pd.DataFrame(rows, columns=cols)

    if not df_pivot.empty:
        st.dataframe(df_pivot, use_container_width=True)

        fig = px.bar(
            df_pivot, 
            x="nghe_si", 
            y=["streaming", "sync_rev", "live_rev"], 
            barmode="stack",
            title="Revenue Sources by Artist",
            template="plotly_dark"
        )
        fig.update_layout(
            plot_bgcolor='rgba(0,0,0,0)',
            paper_bgcolor='rgba(0,0,0,0)',
        )
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No source data available.")

# Top tracks
st.subheader("Top Tracks per Artist")
with st.container(border=True):
    query = f"""
    SELECT * FROM sp_top_tracks_per_artist(3, {year}::INTEGER)
    """

    cols, rows = execute_query(query)
    df_tracks = pd.DataFrame(rows, columns=cols)

    if not df_tracks.empty:
        st.dataframe(df_tracks, use_container_width=True)
    else:
        st.info("No top tracks data available.")

