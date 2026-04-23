import streamlit as st
import pandas as pd
import plotly.express as px
from utils.db import execute_query
from utils.ui import apply_apple_style

st.set_page_config(page_title="Music Revenue Dashboard", layout="wide")
apply_apple_style()

st.title("📊 Music Revenue Dashboard")

# =========================
# Year selector
# =========================
with st.container(border=True):
    year = st.selectbox("Year", [2024, 2025, 2026], index=1)

# =========================
# Total Revenue
# =========================
with st.container(border=True):
    query = f"""
    SELECT COALESCE(SUM(amount),0) AS total_revenue
    FROM revenue_logs
    WHERE EXTRACT(YEAR FROM log_date) = {year}
    """

    cols, rows = execute_query(query)

    total_revenue = 0
    if rows and len(rows) > 0:
        total_revenue = rows[0][0]

    st.metric("💰 Total Revenue", f"{total_revenue:,.0f} VND")

# =========================
# Top Earning Artists
# =========================
st.subheader("🎤 Top Earning Artists")

with st.container(border=True):
    query = f"""
    SELECT *
    FROM sp_top_earning_artists({year}::INTEGER)
    """

    cols, rows = execute_query(query)

    # tạo dataframe an toàn
    df = pd.DataFrame(rows if rows else [], columns=cols if cols else [])

    if not df.empty:
        col1, col2 = st.columns([2, 1])

        with col1:
            fig = px.bar(
                df,
                x="nghe_si",
                y="tong_doanhthu",
                title="Top Artists Revenue",
                text_auto=".2s",
                template="plotly_dark",
                color="tong_doanhthu",
                color_continuous_scale="Blues"
            )

            fig.update_layout(
                xaxis_title="Artist", 
                yaxis_title="Revenue (VND)",
                plot_bgcolor='rgba(0,0,0,0)',
                paper_bgcolor='rgba(0,0,0,0)',
            )

            st.plotly_chart(fig, use_container_width=True)

        with col2:
            st.dataframe(df[["nghe_si", "tong_doanhthu", "so_tracks"]], use_container_width=True)

    else:
        st.warning("⚠️ No data found for this year.")

# =========================
# Revenue by Month
# =========================
st.subheader("📈 Revenue by Month")

with st.container(border=True):
    query = f"""
    SELECT
        TO_CHAR(log_date,'MM') AS month,
        SUM(amount) AS revenue
    FROM revenue_logs
    WHERE EXTRACT(YEAR FROM log_date) = {year}
    GROUP BY month
    ORDER BY month
    """

    cols, rows = execute_query(query)

    df_month = pd.DataFrame(rows if rows else [], columns=cols if cols else [])

    if not df_month.empty:
        fig = px.line(
            df_month, 
            x="month", 
            y="revenue", 
            markers=True, 
            title="Monthly Revenue Trends",
            template="plotly_dark"
        )
        
        fig.update_layout(
            plot_bgcolor='rgba(0,0,0,0)',
            paper_bgcolor='rgba(0,0,0,0)',
        )

        st.plotly_chart(fig, use_container_width=True)

    else:
        st.info("No monthly data available.")

