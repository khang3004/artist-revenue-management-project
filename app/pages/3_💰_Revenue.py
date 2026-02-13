"""
Revenue page - Revenue analytics and reports
"""

import streamlit as st
import pandas as pd
from utils.db import execute_query, call_stored_procedure

st.set_page_config(page_title="Revenue", page_icon="💰", layout="wide")

st.title("💰 Revenue Analytics")
st.markdown("---")

# Revenue overview
st.subheader("Revenue Overview")

col1, col2 = st.columns(2)

with col1:
    st.info("**ROLLUP Query**: Revenue by artist and month")
    st.caption("TODO: Call sp_revenue_rollup() stored procedure")

with col2:
    st.info("**PIVOT Query**: Revenue by source")
    st.caption("TODO: Call sp_revenue_pivot() stored procedure")

st.markdown("---")

# Top artists
st.subheader("Top Revenue Artists")
st.info("TODO: Call sp_top_artists() stored procedure")

st.markdown("---")

# Contract splits
st.subheader("Contract Revenue Distribution")
st.info("TODO: Call sp_contract_splits() stored procedure")
