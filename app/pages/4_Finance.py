import streamlit as st
import pandas as pd
import plotly.express as px
from utils.db import execute_query
from utils.ui import apply_apple_style

st.set_page_config(page_title="Finance", layout="wide")
apply_apple_style()

st.title("🏦 Finance & Contracts")

st.subheader("Contract Revenue Distribution")
with st.container(border=True):
    query = "SELECT * FROM sp_contract_revenue_distribution()"

    cols, rows = execute_query(query)
    df = pd.DataFrame(rows, columns=cols)

    if not df.empty:
        st.dataframe(df, use_container_width=True)
    else:
        st.info("No contract distribution data available.")

st.divider()

st.subheader("Wallet Audit Report")
with st.container(border=True):
    query = "SELECT * FROM sp_wallet_audit_report()"

    cols, rows = execute_query(query)
    df_audit = pd.DataFrame(rows, columns=cols)

    if not df_audit.empty:
        st.dataframe(df_audit, use_container_width=True)

        fig = px.bar(
            df_audit,
            x="nghe_si",
            y="chenh_lech",
            color="trang_thai",
            title="Wallet Balance vs Actual Revenue Discrepancy",
            template="plotly_dark"
        )
        fig.update_layout(
            plot_bgcolor='rgba(0,0,0,0)',
            paper_bgcolor='rgba(0,0,0,0)',
        )
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No audit data available.")
