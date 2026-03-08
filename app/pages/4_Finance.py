import streamlit as st
import pandas as pd
import plotly.express as px
from utils.db import execute_query

st.title("🏦 Finance")

st.subheader("Contract Revenue Distribution")

query = "SELECT * FROM sp_contract_revenue_distribution()"

cols, rows = execute_query(query)
df = pd.DataFrame(rows, columns=cols)

st.dataframe(df)

st.divider()

st.subheader("Wallet Audit Report")

query = "SELECT * FROM sp_wallet_audit_report()"

cols, rows = execute_query(query)
df = pd.DataFrame(rows, columns=cols)

st.dataframe(df)

if not df.empty:
    fig = px.bar(
        df,
        x="nghe_si",
        y="chenh_lech",
        color="trang_thai"
    )
    st.plotly_chart(fig)